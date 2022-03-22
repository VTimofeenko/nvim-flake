-- markdown-specific settings.
-- Configure tabstop and stuff
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	command = "set tabstop=4 | set shiftwidth=4 | set expandtab | set autoindent",
})

-- Map <leader>b to make the selection bold
-- Needs vim-surround
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	command = "vmap <leader>b S*<cr>gvS*",
})
-- Map ]\ to create a quick link
-- Needs vim-surround
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	command = "vmap ]\\ S]%a()<esc>",
})
-- Generic prose config
prose_file_formats = { "markdown" }
for _, file_format in ipairs(prose_file_formats) do
	-- Add endash shortcut
	vim.api.nvim_create_autocmd("FileType", {
		pattern = file_format,
		command = "imap -- – | imap --<Space> –<Space>",
	})
	vim.api.nvim_create_autocmd("FileType", {
		pattern = file_format,
		command = "setlocal spell! spelllang=en_us",
	})
end

