# ==========================================================
# ELC1011 - Trabalho 1: criptografia RC4 em assembly MIPS
# Programa: menu, leitura de nomes de arquivo e senha,
#           criptografia e descriptografia de arquivos (RC4)
# Autores:  Andrei Ribeiro e Caetano Facco da Rosa
# Professor: Giovani Baratto
# ==========================================================

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
    .asciiz "Digite o nome do arquivo de entrada: "

men_nome_arquivo_saida:
    .asciiz "Digite o nome do arquivo de saida: "

men_senha:
    .asciiz "Digite a senha: "

men_arquivo_nao_encontrado:
    .asciiz "Arquivo nao encontrado\n"

# ----- Variaveis -----

var_opcao:
    .space 16

var_arquivo_entrada:
    .space 100

var_arquivo_saida:
    .space 100

var_senha:
    .space 64

# ----- Buffers dos arquivos -----

arq_conteudo_entrada:
    .space 1048576                  # 1 MB

arq_conteudo_saida:
    .space 1048576                  # 1 MB

# ----- Estado do RC4 -----

vetor_estado:
    .space 256                      # vetor S do RC4: permutacao dos valores 0 a 255

.text
.globl main

# ----- main -----
# descricao: fluxo principal do programa; o RC4 e uma cifra de fluxo (XOR com uma
#            sequencia gerada pela senha), entao criptografar e descriptografar sao
#            a mesma operacao e a opcao do menu so muda a mensagem mostrada
# registradores usados: $s1 = fd do arquivo de entrada, $s2 = tamanho dos dados lidos,
#                       $s3 = fd do arquivo de saida

main:
    jal mostrar_menu                    # $v0 = opcao escolhida (1 ou 2), nao usada depois

    la $a0, men_nome_arquivo_entrada    # pede o nome do arquivo de entrada
    la $a1, var_arquivo_entrada
    li $a2, 100
    jal pedir_texto

    la $a0, men_nome_arquivo_saida      # pede o nome do arquivo de saida
    la $a1, var_arquivo_saida
    li $a2, 100
    jal pedir_texto

    la $a0, men_senha                   # pede a senha
    la $a1, var_senha
    li $a2, 64
    jal pedir_texto

    la $a0, var_senha                   # a propria senha e a chave do RC4
    jal inicializar_rc4                 # monta o vetor S a partir da chave (KSA)

    la $a0, var_arquivo_entrada         # abre o arquivo de entrada para leitura
    li $a1, 0
    jal abrir_arquivo
    move $s1, $v0                       # $s1 = fd do arquivo de entrada

    move $a0, $s1                       # le o arquivo de entrada
    la $a1, arq_conteudo_entrada
    li $a2, 1048576
    jal ler_arquivo
    move $s2, $v0                       # $s2 = bytes lidos

    la $a0, arq_conteudo_entrada        # cifra (ou decifra) byte a byte
    la $a1, arq_conteudo_saida
    move $a2, $s2
    jal processar_rc4

    la $a0, var_arquivo_saida           # abre o arquivo de saida para escrita
    li $a1, 1
    jal abrir_arquivo
    move $s3, $v0                       # $s3 = fd do arquivo de saida

    move $a0, $s3                       # grava o resultado
    la $a1, arq_conteudo_saida
    move $a2, $s2
    jal escrever_arquivo

# ----- fim_programa -----
# descricao: encerra o programa

fim_programa:
    li $v0, 10                      # syscall 10: exit
    syscall

# ----- mostrar_menu -----
# entrada: nenhuma
# saida:   $v0 = 1 (criptografar) ou 2 (descriptografar)
# descricao: repete o menu ate a pessoa digitar uma opcao valida

mostrar_menu:
menu_repetir:
    li $v0, 4                       # syscall 4: print_string
    la $a0, menu
    syscall

    li $v0, 8                       # syscall 8: read_string (le a opcao como texto)
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
# descricao: repete o pedido enquanto o texto vier vazio
# registradores salvos: $ra, $s0 a $s2 (guardados na pilha e restaurados no final)

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
    li $v0, 4                       # syscall 4: print_string (imprime a mensagem)
    move $a0, $s0
    syscall

    li $v0, 8                       # syscall 8: read_string (le o texto digitado)
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
# descricao: percorre o texto ate achar '\n' ou o fim; altera $a0

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

# ----- abrir_arquivo -----
# entrada: $a0 = endereco do nome do arquivo, $a1 = flag (0 = leitura, 1 = escrita)
# saida:   $v0 = descritor do arquivo (fd)
# descricao: se o arquivo nao abrir, avisa e encerra o programa

abrir_arquivo:
    li $v0, 13                      # syscall 13: open_file
    li $a2, 0                       # modo (ignorado pelo MARS)
    syscall

    bltz $v0, abrir_arquivo_erro    # fd negativo: nao abriu
    jr $ra

abrir_arquivo_erro:
    li $v0, 4
    la $a0, men_arquivo_nao_encontrado
    syscall

    j fim_programa

# ----- ler_arquivo -----
# entrada: $a0 = fd, $a1 = endereco do buffer, $a2 = tamanho maximo
# saida:   $v0 = quantidade de bytes lidos
# descricao: le o arquivo para o buffer e fecha o arquivo

ler_arquivo:
    li $v0, 14                      # syscall 14: read_file
    syscall

    move $t0, $v0                   # guarda a quantidade lida

    li $v0, 16                      # syscall 16: close_file ($a0 ainda e o fd)
    syscall

    move $v0, $t0
    jr $ra

# ----- escrever_arquivo -----
# entrada: $a0 = fd, $a1 = endereco do buffer, $a2 = quantidade de bytes
# saida:   nenhuma
# descricao: grava o buffer no arquivo e fecha o arquivo

escrever_arquivo:
    li $v0, 15                      # syscall 15: write_file
    syscall

    li $v0, 16                      # syscall 16: close_file ($a0 ainda e o fd)
    syscall

    jr $ra

# ----- inicializar_rc4 -----
# entrada: $a0 = endereco da chave (senha terminada em \0, com pelo menos 1 caractere)
# saida:   vetor_estado embaralhado conforme a chave
# descricao: KSA (Key Scheduling Algorithm) do RC4:
#            S[i] = i para i de 0 a 255; depois, para i de 0 a 255:
#            j = (j + S[i] + chave[i mod tamanho da chave]) mod 256 e troca S[i] com S[j]
#            o "i mod tamanho" e feito voltando ao inicio da chave quando chega no \0

inicializar_rc4:
    la $t0, vetor_estado            # $t0 = endereco de S
    move $t1, $zero                 # $t1 = i
    li $t2, 256                     # $t2 = limite dos lacos

rc4_preencher:
    add $t3, $t0, $t1               # endereco de S[i]
    sb $t1, 0($t3)                  # S[i] = i
    addi $t1, $t1, 1
    bne $t1, $t2, rc4_preencher

    move $t1, $zero                 # $t1 = i
    move $t4, $zero                 # $t4 = j
    move $t5, $a0                   # $t5 = ponteiro do caractere atual da chave

rc4_embaralhar:
    lbu $t6, 0($t5)                 # $t6 = caractere atual da chave
    bnez $t6, rc4_usar_caractere
    move $t5, $a0                   # chegou no \0: volta ao inicio da chave
    lbu $t6, 0($t5)

rc4_usar_caractere:
    add $t3, $t0, $t1               # endereco de S[i]
    lbu $t7, 0($t3)                 # $t7 = S[i]
    add $t4, $t4, $t7               # j = j + S[i]
    add $t4, $t4, $t6               #     + chave[i mod tamanho]
    andi $t4, $t4, 0xFF             #     mod 256

    add $t8, $t0, $t4               # endereco de S[j]
    lbu $t9, 0($t8)                 # $t9 = S[j]
    sb $t9, 0($t3)                  # troca S[i] com S[j]
    sb $t7, 0($t8)

    addi $t5, $t5, 1                # proximo caractere da chave
    addi $t1, $t1, 1                # proximo i
    bne $t1, $t2, rc4_embaralhar

    jr $ra

# ----- processar_rc4 -----
# entrada: $a0 = buffer de entrada, $a1 = buffer de saida, $a2 = quantidade de bytes;
#          inicializar_rc4 ja deve ter sido chamada
# saida:   buffer de saida preenchido
# descricao: PRGA (Pseudo-Random Generation Algorithm) do RC4, um byte por vez:
#            i = (i + 1) mod 256; j = (j + S[i]) mod 256; troca S[i] com S[j];
#            byte da sequencia = S[(S[i] + S[j]) mod 256];
#            saida = entrada XOR byte da sequencia (serve para cifrar e decifrar);
#            altera $a0 e $a1

processar_rc4:
    la $t0, vetor_estado            # $t0 = endereco de S
    move $t1, $zero                 # $t1 = i
    move $t2, $zero                 # $t2 = j
    add $t3, $a0, $a2               # $t3 = endereco final da entrada

processar_laco:
    beq $a0, $t3, processar_fim     # todos os bytes processados

    addi $t1, $t1, 1                # i = (i + 1) mod 256
    andi $t1, $t1, 0xFF
    add $t4, $t0, $t1               # endereco de S[i]
    lbu $t5, 0($t4)                 # $t5 = S[i]
    add $t2, $t2, $t5               # j = (j + S[i]) mod 256
    andi $t2, $t2, 0xFF
    add $t6, $t0, $t2               # endereco de S[j]
    lbu $t7, 0($t6)                 # $t7 = S[j]
    sb $t7, 0($t4)                  # troca S[i] com S[j]
    sb $t5, 0($t6)

    add $t8, $t5, $t7               # (S[i] + S[j]) mod 256
    andi $t8, $t8, 0xFF
    add $t8, $t0, $t8
    lbu $t8, 0($t8)                 # $t8 = byte da sequencia

    lbu $t9, 0($a0)                 # byte de entrada
    xor $t9, $t9, $t8               # aplica o XOR
    sb $t9, 0($a1)                  # grava o byte de saida

    addi $a0, $a0, 1                # proximo byte
    addi $a1, $a1, 1
    j processar_laco

processar_fim:
    jr $ra