
# put this at the top
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    fastfetch
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# Syntax highlighting
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Autosuggestions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# Use standard Emacs-style command-line keybindings
bindkey -e

# Ctrl + Left/Right: move by word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Delete key
bindkey '^[[3~' delete-char

# Home and End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
