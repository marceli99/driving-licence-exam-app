# frozen_string_literal: true

module ApplicationHelper
  def ui_language_switch_path(locale)
    query = request.query_parameters.merge('ui_lang' => locale.to_s).to_query
    query.present? ? "#{request.path}?#{query}" : request.path
  end
end
