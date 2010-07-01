module TaliaCore
  module DataTypes

    # FileRecord that contains a PDF document.
    class PdfData < FileRecord
     
      # The MIME type is always <tt>application/pdf</tt>
      def extract_mime_type(location)
        'application/pdf'
      end

      # Create the PDF data using PDF::Writer. The writer will be passed
      # to the block given to this method, and the resulting PDF will be
      # saved as the record's file.
      def create_from_writer(writer_opts = {})
        activate_pdf
        writer = PDF::Writer.new(writer_opts) do |pdf|
          yield(pdf)
        end
        filename = File.join(Dir.tmpdir, "#{rand 10E16}.pdf")
        writer.save_as(filename)
        self.create_from_file('', filename, true) # set to delete tempfile on create
        self
      end

      private

      # Little helper method to load the pdf writer only when needed. This will make sure
      # the thing is loaded only once, otherwise it would be slow in Rails development
      # (which uses #load for #require)
      def self.activate_pdf
        return if(@pdf_active)
        require 'pdf/writer'
        @pdf_active = true
      end

      # See PdfData.activate_pdf
      def activate_pdf
        self.class.activate_pdf
      end

    end
    
  end
end
