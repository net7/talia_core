xml.instruct!
xml.notebooks do
  for notebook in @notebooks
    xml.notebook(notebook.url)
  end
end