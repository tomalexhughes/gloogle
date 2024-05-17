import data/implementations
import data/kind
import data/model.{type Index, type Model}
import data/msg
import data/search_result
import frontend/colors/palette
import frontend/images
import frontend/strings as frontend_strings
import frontend/view/body/signature
import frontend/view/body/styles as s
import frontend/view/documentation
import frontend/view/types as t
import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/result
import lustre/attribute as a
import lustre/element as el
import lustre/element/html as h
import lustre/event as e

fn view_search_input(model: Model) {
  s.search_wrapper([e.on_submit(msg.SubmitSearch)], [
    s.search_title_wrapper([], [
      s.search_title([], [
        s.search_lucy([a.src("/images/lucy.svg")]),
        s.search_title_with_hint([], [
          h.text("Gloogle"),
          s.pre_alpha_title([], [h.text("Pre Alpha")]),
        ]),
      ]),
      h.text(frontend_strings.gloogle_description),
    ]),
    s.search_input(model.loading, [
      a.placeholder("Search for a function, or a type"),
      e.on_input(msg.UpdateInput),
      a.value(model.input),
    ]),
    s.search_submit([
      a.type_("submit"),
      a.value("Submit"),
      a.disabled(model.loading),
    ]),
  ])
}

fn empty_state(
  image image: String,
  title title: String,
  content content: String,
) {
  s.empty_state([], [
    s.empty_state_lucy([a.src(image)]),
    s.empty_state_titles([], [
      h.div([], [h.text(title)]),
      s.empty_state_subtitle([], [h.text(content)]),
    ]),
  ])
}

pub fn body(model: Model) {
  s.main([], [
    case model.search_results {
      search_result.Start -> view_search_input(model)
      search_result.NoSearchResults ->
        empty_state(
          image: images.internal_error,
          title: "Internal server error",
          content: frontend_strings.internal_server_error,
        )
      search_result.SearchResults([], [], []) ->
        empty_state(
          image: images.shadow_lucy,
          title: "No match found!",
          content: frontend_strings.retry_query,
        )
      search_result.SearchResults(exact, others, searches) -> model.view_cache
    },
  ])
}
