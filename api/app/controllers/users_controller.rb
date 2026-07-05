class UsersController < ApplicationController
  # ponytail: rate_limit nativo Rails 8 por IP — substitui rack-attack do spec, zero gem nova
  rate_limit to: 5, within: 1.minute, only: :create, with: -> {
    Rails.logger.warn("signup: rate limit excedido ip=#{request.remote_ip}")
    render json: { errors: [ "Muitas tentativas. Tente novamente em instantes." ] }, status: :too_many_requests
  }

  def create
    user = User.new(user_params)

    if user.save
      Rails.logger.info("signup: user criado id=#{user.id}")
      render json: user.as_json(only: [ :id, :email, :name ]), status: :created
    else
      Rails.logger.warn("signup: validação falhou (#{user.errors.attribute_names.join(', ')})")
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :name)
  end
end
