import data/model.{type Model}
import data/msg.{type Msg}
import data/search_result
import frontend/router
import frontend/view
import gleam/bool
import gleam/option.{None}
import gleam/pair
import gleam/result
import gleam/uri.{type Uri}
import grille_pain
import grille_pain/lustre/toast
import grille_pain/options
import lustre
import lustre/effect
import lustre/update
import lustre_http as http
import modem
import sketch/lustre as sketch
import sketch/options as sketch_options
import tardis
import toast/error as toast_error

@external(javascript, "./config.ffi.mjs", "is_dev")
fn is_dev() -> Bool

@external(javascript, "./config.ffi.mjs", "scrollTo")
fn scroll_to_element(id: String) -> Nil

@external(javascript, "./config.ffi.mjs", "captureMessage")
fn capture_message(content: String) -> String

pub fn main() {
  let debugger_ = case is_dev() {
    False -> Error(Nil)
    True ->
      tardis.single("Gloogle")
      |> result.nil_error()
  }

  let assert Ok(cache) =
    sketch_options.node()
    |> sketch.setup()

  let assert Ok(_) =
    options.default()
    |> options.timeout(5000)
    |> grille_pain.setup()

  let apply_debugger = fn(app: a, fun: fn(a, tardis.Instance) -> a) {
    result.map(debugger_, fun(app, _))
    |> result.unwrap(app)
  }

  let assert Ok(_) =
    view.view
    |> sketch.compose(cache)
    |> lustre.application(init, update, _)
    |> apply_debugger(tardis.wrap)
    |> lustre.start("#app", Nil)
    |> apply_debugger(tardis.activate)
}

fn init(_) {
  let initial =
    modem.initial_uri()
    |> result.map(router.parse_uri)
    |> result.unwrap(router.Home)
    |> handle_route_change(model.init(), _)
  submit_search(initial.0)
  |> update.add_effect(modem.init(on_url_change))
}

fn on_url_change(uri: Uri) -> Msg {
  router.parse_uri(uri)
  |> msg.OnRouteChange()
}

fn update(model: Model, msg: Msg) {
  case msg {
    msg.UpdateInput(content) -> update_input(model, content)
    msg.SubmitSearch -> submit_search(model)
    msg.Reset -> reset(model)
    msg.None -> update.none(model)
    msg.ScrollTo(id) -> scroll_to(model, id)
    msg.OnRouteChange(route) -> handle_route_change(model, route)
    msg.SearchResults(input, search_results) ->
      handle_search_results(model, input, search_results)
  }
}

fn update_input(model: Model, content: String) {
  model
  |> model.update_input(content)
  |> update.none()
}

fn reset(model: Model) {
  model
  |> model.reset()
  |> update.none()
}

fn submit_search(model: Model) {
  let endpoint = case is_dev() {
    True -> "http://localhost:3000"
    False -> "https://api.gloogle.run"
  }
  use <- bool.guard(when: model.input == "", return: #(model, effect.none()))
  use <- bool.guard(when: model.loading, return: #(model, effect.none()))
  let new_model = model.toggle_loading(model)
  http.expect_json(search_result.decode_search_results, {
    msg.SearchResults(input: model.input, result: _)
  })
  |> http.get(endpoint <> "/search?q=" <> model.input, _)
  |> pair.new(new_model, _)
}

fn scroll_to(model: Model, id: String) {
  let eff = effect.from(fn(_dispatch) { scroll_to_element(id) })
  #(model, eff)
}

fn handle_search_results(
  model: Model,
  input: String,
  search_results: Result(search_result.SearchResults, http.HttpError),
) {
  let toast = display_toast(search_results)
  let up =
    search_results
    |> result.map(model.update_search_results(model, _))
    |> result.map(model.update_route(_, router.Search(input)))
    |> result.unwrap(model)
    |> model.toggle_loading()
    |> update.effect(toast)
  uri.parse("/search?q=" <> input)
  |> result.map(modem.push(_))
  |> result.map(update.add_effect(up, _))
  |> result.unwrap(up)
}

fn handle_route_change(model: Model, route: router.Route) {
  let model = model.update_route(model, route)
  update.none(case route {
    router.Home -> model.update_input(model, "")
    router.Search(q) -> model.update_input(model, q)
  })
}

fn display_toast(
  search_results: Result(search_result.SearchResults, http.HttpError),
) {
  search_results
  |> result.map_error(fn(error) {
    toast_error.describe_http_error(error)
    |> option.map(capture_message)
    |> option.map(toast.error)
  })
  |> result.unwrap_error(option.None)
  |> option.unwrap(effect.none())
}
