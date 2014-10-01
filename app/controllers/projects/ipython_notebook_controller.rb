# Controller for viewing a rendered IPython notebook
class Projects::IpythonNotebookController < Projects::ApplicationController
  include ExtractsPath

  # Authorize
  before_filter :authorize_read_project!
  before_filter :authorize_code_access!
  before_filter :require_non_empty_project

  def show
    @blob = @repository.blob_at(@commit.id, @path)

    if @blob
      # It is a bit of a hassle to get the HTML output from nbconvert. We write
      # the notebook to a temporary file, convert it to HTML in a temporary
      # directory, find the HTML file in that directory and read its contents.
      # Then we remove the temporary file and directory (which now possibly
      # contains support files for the converted notebook that we ignore).
      notebook = Tempfile.new('notebook')
      build_dir = Dir.mktmpdir

      begin
        notebook.write(@blob.data)
        notebook.flush
        command = Gitlab.config.ipython_notebook.nbconvert % \
                  { :build_dir => build_dir, :notebook => notebook.path }
        %x{ #{command} }
        output_file = Dir.glob(build_dir + '/*.html').first
        if output_file.nil?
          redirect_to project_raw_path(@project, @id)
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
      not_found!
    end
  end
end
