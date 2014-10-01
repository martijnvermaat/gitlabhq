# Controller for viewing a rendered IPython notebook
class Projects::IpythonNotebookController < Projects::ApplicationController
  include ExtractsPath

  before_action :require_non_empty_project
  before_action :assign_ref_vars
  before_action :authorize_download_code!

  def show
    @blob = @repository.blob_at(@commit.id, @path)

    if @blob
      if Gitlab.config.ipython_notebook.render && @blob.name.downcase.end_with?('.ipynb')

        # It is a bit of a hassle to get the HTML output from nbconvert. We write
        # the notebook to a temporary file, convert it to HTML in a temporary
        # directory, find the HTML file in that directory and read its contents.
        # Then we remove the temporary file and directory (which now possibly
        # contains support files for the converted notebook that we ignore).
        notebook = Tempfile.new('notebook')
        build_dir = Dir.mktmpdir

        begin
          @blob.load_all_data!(@repository)
          notebook.write(@blob.data)
          notebook.flush
          command = Gitlab.config.ipython_notebook.nbconvert % \
                    { :build_dir => build_dir, :notebook => notebook.path }
          %x{ #{command} }
          output_file = Dir.glob(build_dir + '/*.html').first
          if output_file.nil?
            redirect_to namespace_project_raw_path(@project.namespace, @project, @id)
          else
            send_data(
              File.read(output_file),
              type: 'text/html; charset=utf-8',
              disposition: 'inline',
              filename: 'notebook.html'
            )
          end
        ensure
          notebook.close
          notebook.unlink
          FileUtils.remove_entry build_dir
        end

      else
        redirect_to namespace_project_raw_path(@project.namespace, @project, @id)
      end
    else
      render_404
    end
  end
end
