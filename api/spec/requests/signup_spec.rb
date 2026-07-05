require "rails_helper"

RSpec.describe "POST /signup", type: :request do
  def signup(attrs)
    post "/signup", params: { user: attrs }, as: :json
  end

  def expect_validation_error(campo)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"]).to include(a_string_matching(campo))
  end

  let(:valid_attrs) { { email: "julio@example.com", password: "senha!segura", name: "Julio" } }

  context "com dados válidos" do
    it "retorna 201 com id, email e name, sem password_digest" do
      signup(valid_attrs)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["id"]).to be_present
      expect(body["email"]).to eq("julio@example.com")
      expect(body["name"]).to eq("Julio")
      expect(body).not_to have_key("password_digest")
      expect(body).not_to have_key("password")
    end

    it "cria o User no banco" do
      expect { signup(valid_attrs) }.to change(User, :count).by(1)
    end

    it "normaliza email com strip e downcase" do
      signup(valid_attrs.merge(email: "  JULIO@Example.COM  "))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["email"]).to eq("julio@example.com")
    end

    it "ignora atributos fora do permit (mass assignment)" do
      signup(valid_attrs.merge(id: 999))

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["id"]).not_to eq(999)
    end

    it "aceita senha com exatamente 8 caracteres" do
      signup(valid_attrs.merge(password: "abcdef1!"))

      expect(response).to have_http_status(:created)
    end

    it "aceita senha com exatamente 72 bytes" do
      signup(valid_attrs.merge(password: "!" + "a" * 71))

      expect(response).to have_http_status(:created)
    end
  end

  context "com email inválido" do
    it "retorna 422 quando email está ausente" do
      signup(valid_attrs.except(:email))

      expect_validation_error(/e-?mail/i)
    end

    it "retorna 422 quando email tem formato inválido" do
      signup(valid_attrs.merge(email: "nao-eh-email"))

      expect_validation_error(/e-?mail/i)
    end

    it "retorna 422 quando email já existe com case diferente" do
      User.create!(valid_attrs)
      signup(valid_attrs.merge(email: "JULIO@EXAMPLE.COM"))

      expect_validation_error(/e-?mail/i)
    end
  end

  context "com senha inválida" do
    it "retorna 422 quando senha tem menos de 8 caracteres" do
      signup(valid_attrs.merge(password: "curta!"))

      expect_validation_error(/password|senha/i)
    end

    it "retorna 422 quando senha não tem caractere especial" do
      signup(valid_attrs.merge(password: "somenteletras123"))

      expect_validation_error(/password|senha/i)
    end

    it "retorna 422 quando senha excede 72 bytes" do
      signup(valid_attrs.merge(password: "!" + "a" * 72))

      expect_validation_error(/password|senha/i)
    end

    it "retorna 422 quando senha multibyte excede 72 bytes mesmo com menos de 72 caracteres" do
      # "á" = 2 bytes em UTF-8 → 37 chars, 74 bytes
      signup(valid_attrs.merge(password: "á" * 37))

      expect_validation_error(/password|senha/i)
    end

    it "retorna 422 quando senha está ausente" do
      signup(valid_attrs.except(:password))

      expect_validation_error(/password|senha/i)
    end
  end

  context "com name inválido" do
    it "retorna 422 quando name está ausente" do
      signup(valid_attrs.except(:name))

      expect_validation_error(/name|nome/i)
    end
  end

  context "com payload malformado" do
    it "retorna 400 com JSON de erro quando body está vazio (sem chave user)" do
      post "/signup", as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.content_type).to include("application/json")
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  context "rate limiting" do
    it "retorna 429 na sexta tentativa dentro de 1 minuto" do
      5.times { |i| signup(valid_attrs.merge(email: "user#{i}@example.com")) }
      signup(valid_attrs.merge(email: "user6@example.com"))

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
