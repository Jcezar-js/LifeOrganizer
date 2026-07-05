class ApplicationController < ActionController::API
  rescue_from ActionController::ParameterMissing do |error|
    Rails.logger.warn("request: parâmetro obrigatório ausente (#{error.param})")
    render json: { errors: [ error.message ] }, status: :bad_request
  end
end
