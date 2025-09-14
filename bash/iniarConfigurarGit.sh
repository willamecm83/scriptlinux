#!/bin/bash
# Script final com correção: sobrescrever editor agora funciona e atualiza variáveis
set -e

# ===== Cores =====
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

# ===== Detectar escopo preferencial =====
detect_scope() {
    local in_repo=false
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        in_repo=true
    fi

    if $in_repo && ( git config --local --get user.name >/dev/null 2>&1 || git config --local --get user.email >/dev/null 2>&1 || git config --local --get core.editor >/dev/null 2>&1 || git config --local --get init.defaultBranch >/dev/null 2>&1 ); then
        echo "local"
    elif git config --global --get user.name >/dev/null 2>&1 || git config --global --get user.email >/dev/null 2>&1 || git config --global --get core.editor >/dev/null 2>&1 || git config --global --get init.defaultBranch >/dev/null 2>&1; then
        echo "global"
    elif git config --system --get user.name >/dev/null 2>&1 || git config --system --get user.email >/dev/null 2>&1 || git config --system --get core.editor >/dev/null 2>&1 || git config --system --get init.defaultBranch >/dev/null 2>&1; then
        echo "system"
    else
        # pode haver configurações, mas não as chaves alvo nos escopos acima (merged)
        if git config --list >/dev/null 2>&1; then
            echo "merged"
        else
            echo "nenhum"
        fi
    fi
}

# ===== Função para aplicar config no escopo atual (ou escolhido se merged) =====
set_config() {
    local key="$1"
    local value="$2"
    local write_scope="$SCOPE"

    if [[ "$SCOPE" == "merged" ]]; then
        # se merged, pergunte onde gravar para não alterar comportamento invisivelmente
        while true; do
            echo -e "${YELLOW}Configurações vêm de múltiplos escopos (merged). Em qual escopo deseja gravar?${RESET}"
            echo "1) local"
            echo "2) global"
            echo "3) system"
            read -p "Escolha (1/2/3): " schoice
            case "$schoice" in
                1) write_scope="local"; break ;;
                2) write_scope="global"; break ;;
                3) write_scope="system"; break ;;
                *) echo -e "${RED}Opção inválida. Tente novamente.${RESET}" ;;
            esac
        done
    fi

    # executa o git config e reporta erro sem quebrar o script (tratamos o erro)
    if [[ "$write_scope" == "local" || "$write_scope" == "global" || "$write_scope" == "system" ]]; then
        git config --"$write_scope" "$key" "$value" 2>/tmp/gitcfg_err || true
        status=$?
    else
        # fallback: sem escopo explícito (git decide)
        git config "$key" "$value" 2>/tmp/gitcfg_err || true
        status=$?
    fi

    if [[ $status -ne 0 ]]; then
        echo -e "${RED}Falha ao gravar '${key}' no escopo ${write_scope}.${RESET}"
        echo -e "${YELLOW}Mensagem do git:${RESET}"
        sed -n '1,200p' /tmp/gitcfg_err
        echo
        if [[ "$write_scope" == "system" ]]; then
            echo -e "${YELLOW}Nota: gravar em --system geralmente exige permissão de administrador (sudo).${RESET}"
        fi
    else
        # atualização bem-sucedida: forçar refresh das variáveis
        refresh_vars "$write_scope"
    fi

    # limpar arquivo temporário
    rm -f /tmp/gitcfg_err 2>/dev/null || true
}

# ===== Função para recarregar NAME, EMAIL, BRANCH, EDITOR a partir de um escopo (ou SCOPE atual) =====
refresh_vars() {
    local scope_to_read="${1:-$SCOPE}"

    case "$scope_to_read" in
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
        *)
            NAME=""; EMAIL=""; BRANCH=""; EDITOR=""
            ;;
    esac
}

# ===== Mostrar configuração atual (usa variáveis) =====
mostrar_configuracoes() {
    echo -e "${CYAN}===== Configurações atuais =====${RESET}"
    echo -e "${YELLOW}Escopo detectado:${RESET} ${SCOPE}"
    echo -e "${YELLOW}Nome:${RESET} ${NAME:-<não definido>}"
    echo -e "${YELLOW}Email:${RESET} ${EMAIL:-<não definido>}"
    echo -e "${YELLOW}Branch padrão:${RESET} ${BRANCH:-<não definido>}"
    echo -e "${YELLOW}Editor padrão:${RESET} ${EDITOR:-<não definido>}"
    echo
}

# ===== configurar editor com validação e refresh =====
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
            1)
                set_config core.editor "nano -w"
                break
                ;;
            2)
                set_config core.editor "vim --nofork"
                break
                ;;
            3)
                set_config core.editor "code --wait"
                break
                ;;
            4)
                set_config core.editor "atom --wait"
                break
                ;;
            m|M)
                read -p "Digite o editor (ex: nano -w, vim --nofork, code --wait, atom --wait): " MANUAL_EDITOR
                if [[ -z "$MANUAL_EDITOR" ]]; then
                    echo -e "${RED}Entrada vazia. Tente novamente.${RESET}"
                    continue
                fi
                set_config core.editor "$MANUAL_EDITOR"
                break
                ;;
            *)
                echo -e "${RED}Opção inválida. Tente novamente.${RESET}"
                ;;
        esac
    done

    # depois de qualquer alteração, garanta que as variáveis reflitam o novo estado
    refresh_vars
    echo -e "${GREEN}Editor atualizado. Visualização atualizada.${RESET}"
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

# Detecta escopo inicial e carrega variáveis
SCOPE=$(detect_scope)
refresh_vars "$SCOPE"

# mostra sempre no início
mostrar_configuracoes

# ===== Função sobrescrever =====
sobrescrever_config() {
    if [[ "$SCOPE" == "nenhum" ]]; then
        echo -e "${RED}Para sobrescrever precisa ter alguma configuração.${RESET}"
        echo -e "${YELLOW}Por favor, escolha a opção 3 (Configurar do zero).${RESET}"
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
            1)
                read -p "Digite o novo nome completo: " NEW_NAME
                set_config user.name "$NEW_NAME"
                echo -e "${GREEN}Nome atualizado.${RESET}"
                ;;
            2)
                read -p "Digite o novo email: " NEW_EMAIL
                set_config user.email "$NEW_EMAIL"
                echo -e "${GREEN}Email atualizado.${RESET}"
                ;;
            3)
                read -p "Digite o novo branch padrão: " NEW_BRANCH
                set_config init.defaultBranch "$NEW_BRANCH"
                echo -e "${GREEN}Branch padrão atualizado.${RESET}"
                ;;
            4)
                configurar_editor
                ;;
            5)
                return
                ;;
            6)
                echo -e "${RED}Encerrando programa.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opção inválida. Tente novamente.${RESET}"
                ;;
        esac

        # sempre atualizar SCOPE (caso tenha sido merged e user escolheu gravar em outro scope)
        SCOPE=$(detect_scope)
        refresh_vars "$SCOPE"
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
                1) write_scope="local" ;;
                2) write_scope="global" ;;
                3) write_scope="system" ;;
                *) echo -e "${RED}Opção inválida, voltando ao menu principal.${RESET}"; return ;;
            esac

            # primeiro unsets no escopo escolhido (garantir limpeza)
            git config --"$write_scope" --unset-all user.name 2>/dev/null || true
            git config --"$write_scope" --unset-all user.email 2>/dev/null || true
            git config --"$write_scope" --unset-all init.defaultBranch 2>/dev/null || true
            git config --"$write_scope" --unset-all core.editor 2>/dev/null || true

            # solicitar novas configurações
            read -p "Digite seu nome e sobrenome: " NAME
            git config --"$write_scope" user.name "$NAME"
            read -p "Digite seu email: " EMAIL
            git config --"$write_scope" user.email "$EMAIL"
            read -p "Digite o nome do branch padrão: " BRANCH
            git config --"$write_scope" init.defaultBranch "$BRANCH"

            # configurar editor via função que usa set_config (para reutilizar validações)
            # temporariamente guardamos SCOPE para que set_config grave no escopo escolhido
            OLD_SCOPE="$SCOPE"
            SCOPE="$write_scope"
            configurar_editor
            SCOPE="$OLD_SCOPE"

            # refletir as alterações
            SCOPE=$(detect_scope)
            refresh_vars "$SCOPE"
            echo -e "${GREEN}Configurações redefinidas com sucesso!${RESET}"
            mostrar_configuracoes
            ;;
        *)
            echo -e "${YELLOW}Operação cancelada. Voltando ao menu principal.${RESET}"
            ;;
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

    # garantir refresh
    SCOPE=$(detect_scope)
    refresh_vars "$SCOPE"
    echo -e "${GREEN}Configuração do zero realizada com sucesso!${RESET}"
    mostrar_configuracoes
}

# ===== Menu principal =====
menu_principal() {
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