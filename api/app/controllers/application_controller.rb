class ApplicationController < ActionController::API
  # RecordInvalid não tratado = bug interno (validação de usuário usa save + 422).
  # Falha de sistema: 500 genérico pro client, detalhe completo só no log.
  rescue_from ActiveRecord::RecordInvalid do |error|
    Rails.logger.error("erro de sistema: #{error.class} — #{error.message}")
    render json: { errors: [ "Erro interno. Tente novamente." ] }, status: :internal_server_error
  end

  rescue_from ActionController::ParameterMissing do |error|
    Rails.logger.warn("request: parâmetro obrigatório ausente (#{error.param})")
    render json: { errors: [ error.message ] }, status: :bad_request
  end
end
