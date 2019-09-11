class Cms::PostsController < Cms::BaseController
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  def index
    @cms_posts = Post.all
  end

  def new
    @cms_post = Post.new
  end

  def show
    @cms_post = Post.find(params[:id])
  end

  def edit
    @cms_post = Post.find(params[:id])
  end

  def create
    @cms_post = Post.new(cms_post_params)
    @cms_post.save
    if @cms_post.errors.empty?
      redirect_to cms_posts_path
    else
      flash[:danger] = @cms_post.errors.full_messages.to_sentence
      render :new
    end
  end

  def update
    @cms_post = Post.find(params[:id])
    @cms_post.attributes = cms_post_params
    @cms_post.save
    if @cms_post.errors.empty?
      flash[:success] = "#{@cms_post.title} successfully updated!"
      redirect_to cms_posts_path
    else
      render :new
    end
  end

  def destroy
    @cms_post = Post.find(params[:id])
    @cms_post.destroy
    if @cms_post.errors.empty?
      flash[:success] = "#{@cms_post.title} successfully deleted!"
    else
      flash[:danger] = @cms_post.errors.full_messages.to_sentence
    end
    redirect_to cms_posts_path
  end

  private

  def handle_record_not_found
    flash[:danger] = 'Post not found!'
    redirect_to cms_posts_path
  end

  def cms_post_params
    params.require(:post).permit(
      :title,
      :publish_date,
      :content
    )
  end
end
