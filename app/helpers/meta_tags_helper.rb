module MetaTagsHelper
  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : DEFAULT_META["meta_title"]
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : DEFAULT_META["meta_description"]
  end

  def meta_image
    meta_image = (content_for?(:meta_image) ? content_for(:meta_image) : DEFAULT_META["meta_image"])
    # little twist to make it work equally with an asset or a url
    meta_image.starts_with?("http") ? meta_image : image_url(meta_image)
  end

  # OpenGraph helper methods
  def og_title
    content_for?(:og_title) ? content_for(:og_title) : meta_title
  end

  def og_description
    content_for?(:og_description) ? content_for(:og_description) : meta_description
  end

  def og_image
    content_for?(:og_image) ? content_for(:og_image) : meta_image
  end

  def og_url
    content_for?(:og_url) ? content_for(:og_url) : request.url
  end

  def og_site_name
    DEFAULT_META["meta_site_name"] || DEFAULT_META["meta_name"]
  end

  def og_type
    content_for?(:og_type) ? content_for(:og_type) : "website"
  end
end
