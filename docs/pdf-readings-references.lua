function Pandoc(document)
  if FORMAT:match("latex") then
    -- Add the PDF bibliography insertion point after all book chapters.
    table.insert(document.blocks, pandoc.Div({}, pandoc.Attr("refs")))
  end

  return document
end
