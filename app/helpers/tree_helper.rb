module TreeHelper
  # Sorts a repository's tree so that folders are before files and renders
  # their corresponding partials
  #
  # contents - A Grit::Tree object for the current tree
  def render_tree(tree)
    # Render Folders before Files/Submodules
    folders, files, submodules = tree.trees, tree.blobs, tree.submodules

    tree = ""

    # Render folders if we have any
    tree += render partial: 'projects/tree/tree_item', collection: folders, locals: {type: 'folder'} if folders.present?

    # Render files if we have any
    tree += render partial: 'projects/tree/blob_item', collection: files, locals: {type: 'file'} if files.present?

    # Render submodules if we have any
    tree += render partial: 'projects/tree/submodule_item', collection: submodules if submodules.present?

    tree.html_safe
  end

  # Return an image icon depending on the file type
  #
  # type - String type of the tree item; either 'folder' or 'file'
  def tree_icon(type)
    icon_class = if type == 'folder'
                   'icon-folder-close'
                 else
                   'icon-file-alt'
                 end

    content_tag :i, nil, class: icon_class
  end

  def tree_hex_class(content)
    "file_#{hexdigest(content.name)}"
  end

  # Public: Determines if a given filename is compatible with GitHub::Markup.
  #
  # filename - Filename string to check
  #
  # Returns boolean
  def markup?(filename)
    filename.downcase.end_with?(*%w(.textile .rdoc .org .creole
                                    .mediawiki .rst .adoc .asciidoc .pod))
  end

  def gitlab_markdown?(filename)
    filename.downcase.end_with?(*%w(.mdown .md .markdown))
  end

  def plain_text_readme? filename
    filename =~ /^README(.txt)?$/i
  end

  def ipython_notebook?(filename)
    filename.downcase.end_with?('.ipynb')
  end

  def render_notebook(data)
    # It is a bit of a hassle to get the HTML output from nbconvert. We write
    # the notebook to a temporary file, convert it to HTML in a temporary
    # directory, find the HTML file in that directory and read its contents.
    # Then we remove the temporary file and directory (which now possibly
    # contains support files for the converted notebook that we ignore).
    error_doc = <<END
<!DOCTYPE html>
<html>
<head><meta charset=\"UTF-8\"></head>
<style>
p {
  padding: 20px;
  font-family: "Helvetica Neue",Helvetica,Arial,sans-serif;
  font-size: 14px;
  line-height: 18px;
}
</style>
<body>
<p>Sorry, could not render this notebook.</p>
</body>
</html>
END

    notebook = Tempfile.new('notebook')
    build_dir = Dir.mktmpdir

    begin
      notebook.write(data)
      notebook.flush
      command = Gitlab.config.ipython_notebook.nbconvert % \
                { :build_dir => build_dir, :notebook => notebook.path }
      %x{ #{command} }
      output_file = Dir.glob(build_dir + '/*.html').first
      output_file.nil? ? error_doc : File.read(output_file)
    ensure
      notebook.close
      notebook.unlink
      FileUtils.remove_entry build_dir
    end
  end

  # Simple shortcut to File.join
  def tree_join(*args)
    File.join(*args)
  end

  def allowed_tree_edit?
    return false unless @repository.branch_names.include?(@ref)

    if @project.protected_branch? @ref
      can?(current_user, :push_code_to_protected_branches, @project)
    else
      can?(current_user, :push_code, @project)
    end
  end

  def tree_breadcrumbs(tree, max_links = 2)
    if @path.present?
      part_path = ""
      parts = @path.split("\/")

      yield('..', nil) if parts.count > max_links

      parts.each do |part|
        part_path = File.join(part_path, part) unless part_path.empty?
        part_path = part if part_path.empty?

        next unless parts.last(2).include?(part) if parts.count > max_links
        yield(part, tree_join(@ref, part_path))
      end
    end
  end

  def up_dir_path tree
    file = File.join(@path, "..")
    tree_join(@ref, file)
  end

  def leave_edit_message
    "Leave edit mode?\nAll unsaved changes will be lost."
  end

  def editing_preview_title(filename)
    if gitlab_markdown?(filename) || markup?(filename)
      'Preview'
    else
      'Diff'
    end
  end
end
