module ApplicationHelper
  def ui_language_switch_path(locale)
    query = request.query_parameters.merge("ui_lang" => locale.to_s).to_query
    query.present? ? "#{request.path}?#{query}" : request.path
  end

  def ui_language_active?(locale)
    I18n.locale.to_s == locale.to_s
  end
end
