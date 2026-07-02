class SignupsController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    unless @user.save
      render :new, status: :unprocessable_entity and return
    end

    ai_content = WelcomeEmailGenerator.new(@user).call

    begin
      WelcomeMailer.deliver(@user, ai_content)
      @user.update!(welcome_email_status: "sent")
    rescue => e
      Rails.logger.error("Welcome mail failed for user #{@user.id}: #{e.class} - #{e.message}")
      @user.update!(welcome_email_status: "failed")
    end

    redirect_to signup_success_path(user_id: @user.id)
  end

  def success
    @user = User.find(params[:user_id])
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role, :company_size, :use_case)
  end
end
