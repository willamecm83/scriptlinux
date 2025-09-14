#!/bin/bash
set -e

# ===== Cores =====
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# ===== Função auxiliar para aplicar configuração no escopo =====
set_config() {
    local key="$1"
    local value="$2"
    case "$SCOPE" in
        local) git config --local "$key" "$value" ;;
        global) git config --global "$key" "$value" ;;
        system) git config --system "$key" "$value" ;;
        merged) git config "$key" "$value" ;;
        *) echo -e "${RED}Nenhum escopo válido detectado!${RESET}" ;;
    esac
}

# ===== Função mostrar configurações =====
mostrar_configuracoes() {
    echo -e "${CYAN}===== Configurações atuais =====${RESET}"
    echo -e "${YELLOW}Escopo:${RESET} $SCOPE"
    echo -e "${YELLOW}Nome:${RESET} ${NAME:-<não definido>}"
    echo -e "${YELLOW}Email:${RESET} ${EMAIL:-<não definido>}"
    echo -e "${YELLOW}Branch padrão:${RESET} ${BRANCH:-<não definido>}"
    echo -e "${YELLOW}Editor padrão:${RESET} ${EDITOR:-<não definido>}"
    echo
}

# ===== Função configurar editor =====
configurar_editor() {
    while true; do
        echo
        echo -e "${CYAN}Escolha o editor padrão ou digite 'm' para entrada manual:${RESET}"
        echo "1) Nano (nano -w)"
        echo "2) Vim (vim --nofork)"
        echo "3) Visual Studio Code (code --wait)"
        echo "4) Atom (atom --wait)"
        echo "m) Digitar manualmente"
        read -p "Opção: " editor_choice

        case "$editor_choice" in
            1) set_config core.editor "nano -w"; echo -e "${GREEN}Editor atualizado para: nano -w${RESET}"; break ;;
            2) set_config core.editor "vim --nofork"; echo -e "${GREEN}Editor atualizado para: vim --nofork${RESET}"; break ;;
            3) set_config core.editor "code --wait"; echo -e "${GREEN}Editor atualizado para: code --wait${RESET}"; break ;;
            4) set_config core.editor "atom --wait"; echo -e "${GREEN}Editor atualizado para: atom --wait${RESET}"; break ;;
            m|M) read -p "Digite o editor: " MANUAL_EDITOR; [[ -z "$MANUAL_EDITOR" ]] && echo -e "${RED}Entrada vazia. Tente novamente.${RESET}" && continue; set_config core.editor "$MANUAL_EDITOR"; echo -e "${GREEN}Editor atualizado para: $MANUAL_EDITOR${RESET}"; break ;;
            *) echo -e "${RED}Opção inválida. Tente novamente.${RESET}" ;;
        esac
    done
}

# ===== Etapa 1: git init + detectar configurações =====
echo -e "${CYAN}=== Inicializando repositório Git (git init) ===${RESET}"
read -p "Digite o caminho do diretório (Enter para atual): " TARGET_DIR
if [[ -n "$TARGET_DIR" ]]; then
    mkdir -p "$TARGET_DIR"
    cd "$TARGET_DIR" || { echo "Não foi possível acessar o diretório."; exit 1; }
fi

git init >/dev/null 2>&1 || true
echo -e "${GREEN}Repositório inicializado em: $(pwd)${RESET}"
echo

# ===== Detectar configurações existentes =====
ALL_CONFIGS=$(git config --list 2>/dev/null || true)

SCOPE="nenhum"
NAME=""
EMAIL=""
BRANCH=""
EDITOR=""

if [[ -z "$ALL_CONFIGS" ]]; then
    SCOPE="nenhum"
    echo -e "${YELLOW}Você não possui nenhuma configuração padrão.${RESET}"
else
    # Detectar escopo
    IN_REPO=false
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        IN_REPO=true
    fi

    if $IN_REPO && ( git config --local --get user.name >/dev/null 2>&1 || git config --local --get user.email >/dev/null 2>&1 || git config --local --get core.editor >/dev/null 2>&1 || git config --local --get init.defaultBranch >/dev/null 2>&1 ); then
        SCOPE="local"
    elif git config --global --get user.name >/dev/null 2>&1 || git config --global --get user.email >/dev/null 2>&1 || git config --global --get core.editor >/dev/null 2>&1 || git config --global --get init.defaultBranch >/dev/null 2>&1; then
        SCOPE="global"
    elif git config --system --get user.name >/dev/null 2>&1 || git config --system --get user.email >/dev/null 2>&1 || git config --system --get core.editor >/dev/null 2>&1 || git config --system --get init.defaultBranch >/dev/null 2>&1; then
        SCOPE="system"
    else
        SCOPE="merged"
    fi

    # Extrair valores
    case "$SCOPE" in
        local)
            NAME=$(git config --local user.name 2>/dev/null || true)
            EMAIL=$(git config --local user.email 2>/dev/null || true)
            BRANCH=$(git config --local init.defaultBranch 2>/dev/null || true)
            EDITOR=$(git config --local core.editor 2>/dev/null || true)
            ;;
        global)
            NAME=$(git config --global user.name 2>/dev/null || true)
            EMAIL=$(git config --global user.email 2>/dev/null || true)
            BRANCH=$(git config --global init.defaultBranch 2>/dev/null || true)
            EDITOR=$(git config --global core.editor 2>/dev/null || true)
            ;;
        system)
            NAME=$(git config --system user.name 2>/dev/null || true)
            EMAIL=$(git config --system user.email 2>/dev/null || true)
            BRANCH=$(git config --system init.defaultBranch 2>/dev/null || true)
            EDITOR=$(git config --system core.editor 2>/dev/null || true)
            ;;
        merged)
            NAME=$(git config user.name 2>/dev/null || true)
            EMAIL=$(git config user.email 2>/dev/null || true)
            BRANCH=$(git config init.defaultBranch 2>/dev/null || true)
            EDITOR=$(git config core.editor 2>/dev/null || true)
            ;;
    esac
fi

# ===== Função sobrescrever =====
sobrescrever_config() {
    if [[ "$SCOPE" == "nenhum" ]]; then
        echo -e "${RED}Para sobrescrever precisa ter alguma configuração.${RESET}"
        echo -e "${YELLOW}Escolha a opção 3 (Configurar do zero) caso não haja configuração.${RESET}"
        return
    fi

    while true; do
        echo
        echo -e "${CYAN}O que você quer mudar?${RESET}"
        echo "1. Nome"
        echo "2. Email"
        echo "3. Branch padrão"
        echo "4. Editor padrão"
        echo "5. Voltar ao menu inicial"
        echo "6. Encerrar programa"
        read -p "Escolha uma opção: " choice

        case $choice in
            1) read -p "Digite o novo nome: " NAME; set_config user.name "$NAME"; echo -e "${GREEN}Nome atualizado para: $NAME${RESET}" ;;
            2) read -p "Digite o novo email: " EMAIL; set_config user.email "$EMAIL"; echo -e "${GREEN}Email atualizado para: $EMAIL${RESET}" ;;
            3) read -p "Digite o novo branch padrão: " BRANCH; set_config init.defaultBranch "$BRANCH"; echo -e "${GREEN}Branch atualizado para: $BRANCH${RESET}" ;;
            4) configurar_editor ;;
            5) break ;;
            6) echo -e "${RED}Programa encerrado.${RESET}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida.${RESET}" ;;
        esac
        mostrar_configuracoes
    done
}

# ===== Função resetar =====
resetar_config() {
    if [[ "$SCOPE" == "nenhum" ]]; then
        echo -e "${RED}Você não tem nenhuma configuração.${RESET}"
        echo -e "${YELLOW}No menu principal escolha a opção 3 para configurar do zero.${RESET}"
        return
    fi

    read -p "Ao realizar essa opção todas as configurações serão apagadas, quer continuar (s/n)? " RESP
    case "$RESP" in
        s|S)
            echo -e "${YELLOW}Escolha o escopo para aplicar as novas configurações:${RESET}"
            echo "1) local"
            echo "2) global"
            echo "3) system"
            read -p "Opção: " ESC_OPCAO
            case "$ESC_OPCAO" in
                1) SCOPE="local" ;;
                2) SCOPE="global" ;;
                3) SCOPE="system" ;;
                *) echo -e "${RED}Opção inválida, voltando ao menu principal.${RESET}"; return ;;
            esac

            read -p "Digite seu nome e sobrenome: " NAME
            set_config user.name "$NAME"
            read -p "Digite seu email: " EMAIL
            set_config user.email "$EMAIL"
            read -p "Digite o nome do branch padrão: " BRANCH
            set_config init.defaultBranch "$BRANCH"
            configurar_editor

            echo -e "${GREEN}Configurações redefinidas com sucesso!${RESET}"
            mostrar_configuracoes
            ;;
        *) echo -e "${YELLOW}Operação cancelada. Voltando ao menu principal.${RESET}" ;;
    esac
}

# ===== Função configurar do zero =====
configurar_zero() {
    if [[ "$SCOPE" != "nenhum" ]]; then
        echo -e "${RED}Você possui configurações.${RESET}"
        echo -e "${YELLOW}Você pode escolher para sobrescrever (opção 1) ou resetar (opção 2).${RESET}"
        return
    fi

    echo -e "${CYAN}Escolha o escopo para a configuração:${RESET}"
    echo "1) local"
    echo "2) global"
    echo "3) system"
    read -p "Opção: " ESC_OPCAO
    case "$ESC_OPCAO" in
        1) SCOPE="local" ;;
        2) SCOPE="global" ;;
        3) SCOPE="system" ;;
        *) echo -e "${RED}Opção inválida, retornando ao menu principal.${RESET}"; return ;;
    esac

    read -p "Digite seu nome e sobrenome: " NAME
    set_config user.name "$NAME"
    read -p "Digite seu email: " EMAIL
    set_config user.email "$EMAIL"
    read -p "Digite o nome do branch padrão: " BRANCH
    set_config init.defaultBranch "$BRANCH"
    configurar_editor

    echo -e "${GREEN}Configuração do zero realizada com sucesso!${RESET}"
    mostrar_configuracoes
}

# ===== Menu principal =====
menu_principal() {
    mostrar_configuracoes   # <- Exibe sempre as configs atuais antes do menu
    while true; do
        echo
        echo -e "${CYAN}===== MENU PRINCIPAL =====${RESET}"
        echo "1) Sobrescrever configurações"
        echo "2) Resetar configurações"
        echo "3) Configurar do zero"
        echo "4) Encerrar programa"
        read -p "Escolha uma opção: " OPT

        case "$OPT" in
            1) sobrescrever_config ;;
            2) resetar_config ;;
            3) configurar_zero ;;
            4) echo -e "${RED}Programa encerrado.${RESET}"; exit 0 ;;
            *) echo -e "${RED}Opção inválida. Tente novamente.${RESET}" ;;
        esac
    done
}

# ===== Início =====
menu_principal