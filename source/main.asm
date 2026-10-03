.data

# ----- Mensagens -----

# strings sob o mesmo rotulo ficam coladas na memoria; so a ultima (.asciiz) termina com \0
menu:
    .ascii  "Bem-vindo! Selecione uma opcao:\n"
    .ascii  "1 - Criptografar arquivo\n"
    .ascii  "2 - Descriptografar arquivo\n"
    .asciiz "Sua escolha: "

men_criptografar:
    .asciiz "Voce escolheu criptografar\n"

men_descriptografar:
    .asciiz "Voce escolheu descriptografar\n"

men_invalida:
    .asciiz "Opcao invalida\n"

men_vazio:
    .asciiz "Entrada vazia, tente novamente\n"

men_nome_arquivo_entrada:
    .asciiz "Digite o nome do arquivo de entrada:\n"

men_nome_arquivo_saida:
    .asciiz "Digite o nome do arquivo de saida\n"

men_senha:
    .asciiz "Digite a senha\n"

# usados so na depuracao dos textos lidos
texto_abre_colchete:
    .asciiz "["

texto_fecha_colchete:
    .asciiz "]\n"

# ----- Variaveis -----

var_opcao:
    .space 16

var_arquivo_entrada:
    .space 100

var_arquivo_saida:
    .space 100

var_senha:
    .space 64

.text
.globl main

# ----- Programa principal -----

main:

    # Mostra o menu principal

    jal mostrar_menu                # $v0 = opcao escolhida (1 ou 2)
    move $s0, $v0                   # $s0 guarda a opcao para o resto do programa

    # Pede o nome do arquivo de input

    la $a0, men_nome_arquivo_entrada
    la $a1, var_arquivo_entrada
    li $a2, 100
    jal pedir_texto

    # Pede o nome do arquivo de output

    la $a0, men_nome_arquivo_saida
    la $a1, var_arquivo_saida
    li $a2, 100
    jal pedir_texto

    # Pede a senha

    la $a0, men_senha
    la $a1, var_senha
    li $a2, 64
    jal pedir_texto

    la $a0, var_arquivo_entrada     # depuracao: mostra [texto] de cada leitura
    jal depurar_texto
    la $a0, var_arquivo_saida
    jal depurar_texto
    la $a0, var_senha
    jal depurar_texto

    li $v0, 10                      # syscall 10: encerra o programa
    syscall

# ----- mostrar_menu -----
# entrada: nenhuma
# saida:   $v0 = 1 (criptografar) ou 2 (descriptografar)
# repete o menu ate a pessoa digitar uma opcao valida

mostrar_menu:
menu_repetir:
    li $v0, 4
    la $a0, menu
    syscall

    li $v0, 8                       # le a opcao como texto
    la $a0, var_opcao
    li $a1, 16
    syscall

    la $t0, var_opcao
    lbu $t1, 0($t0)                 # $t1 = primeiro caractere digitado
    lbu $t2, 1($t0)                 # $t2 = segundo caractere digitado

    li $t3, 10                      # 10 = '\n' (Enter)
    beq $t2, $t3, menu_verificar    # so um caractere digitado: segue
    beq $t2, $zero, menu_verificar  # texto acabou: segue
    j menu_invalida                 # sobrou algo depois do primeiro caractere

menu_verificar:
    li $t3, 49                      # 49 = '1'
    beq $t1, $t3, menu_criptografar
    li $t3, 50                      # 50 = '2'
    beq $t1, $t3, menu_descriptografar
                                    # nenhuma bateu: cai em menu_invalida

menu_invalida:
    li $v0, 4
    la $a0, men_invalida
    syscall
    j menu_repetir

menu_criptografar:
    li $v0, 4
    la $a0, men_criptografar
    syscall
    li $t4, 1                       # resultado: opcao 1
    j menu_fim

menu_descriptografar:
    li $v0, 4
    la $a0, men_descriptografar
    syscall
    li $t4, 2                       # resultado: opcao 2

menu_fim:
    move $v0, $t4                   # $v0 so recebe o resultado no final
    jr $ra

# ----- pedir_texto -----
# entrada: $a0 = endereco da mensagem, $a1 = endereco do buffer, $a2 = tamanho maximo
# saida:   texto digitado no buffer, sem o '\n' e nunca vazio
# repete o pedido enquanto o texto vier vazio
# usa $s0 a $s2 para guardar os argumentos durante o laco, entao salva
# os valores antigos deles (e o $ra) na pilha e restaura no final

pedir_texto:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    move $s0, $a0                   # $s0 = mensagem
    move $s1, $a1                   # $s1 = buffer
    move $s2, $a2                   # $s2 = tamanho maximo

pedir_repetir:
    li $v0, 4                       # imprime a mensagem
    move $a0, $s0
    syscall

    li $v0, 8                       # le o texto digitado
    move $a0, $s1
    move $a1, $s2
    syscall

    move $a0, $s1                   # tira o '\n' do final
    jal tirar_barra_n

    lbu $t0, 0($s1)                 # primeiro byte do texto
    bne $t0, $zero, pedir_fim       # nao e 0: texto valido

    li $v0, 4                       # texto vazio: avisa e pede de novo
    la $a0, men_vazio
    syscall
    j pedir_repetir

pedir_fim:
    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# ----- tirar_barra_n -----
# entrada: $a0 = endereco do texto
# saida:   o primeiro '\n' do texto vira \0

tirar_barra_n:
    li $t2, 10                      # $t2 = '\n', fica fixo durante o laco

tirar_laco:
    lbu $t1, 0($a0)                 # le o caractere atual
    beq $t1, $zero, tirar_fim       # fim do texto sem '\n'
    beq $t1, $t2, tirar_trocar      # achou o '\n'
    addi $a0, $a0, 1                # avanca para o proximo caractere
    j tirar_laco

tirar_trocar:
    sb $zero, 0($a0)                # troca o '\n' por \0

tirar_fim:
    jr $ra

# ----- depurar_texto -----
# entrada: $a0 = endereco do texto
# saida:   imprime [texto] na tela

depurar_texto:
    move $t0, $a0                   # guarda o texto antes de usar $a0 nas syscalls

    li $v0, 4
    la $a0, texto_abre_colchete
    syscall

    li $v0, 4
    move $a0, $t0
    syscall

    li $v0, 4
    la $a0, texto_fecha_colchete
    syscall

    jr $ra