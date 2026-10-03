# ==========================================================
# ELC1011 - Trabalho 1: criptografia S-AES em assembly MIPS
# Programa: menu, leitura de nomes de arquivo e senha,
#           criptografia e descriptografia de arquivos (S-AES, modo ECB)
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

men_arquivo_invalido:
    .asciiz "Arquivo cifrado invalido ou senha incorreta\n"

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

# ----- Tabelas do S-AES -----

tabela_sbox:
    .byte 0x9, 0x4, 0xA, 0xB, 0xD, 0x1, 0x8, 0x5, 0x6, 0x2, 0x0, 0x3, 0xC, 0xE, 0xF, 0x7

tabela_sbox_inversa:
    .byte 0xA, 0x5, 0x9, 0xB, 0x1, 0x7, 0x8, 0xF, 0x6, 0x0, 0x2, 0x3, 0xC, 0x4, 0xD, 0xE

chaves_rodada:
    .word 0, 0, 0

.text
.globl main

# ----- main -----
# descricao: fluxo principal do programa
# registradores salvos: $s0 = opcao do menu, $s1 = fd do arquivo de entrada,
#                       $s2 = tamanho dos dados (lido, com ou sem padding),
#                       $s3 = fd do arquivo de saida

main:
    jal mostrar_menu                # $v0 = opcao escolhida (1 ou 2)
    move $s0, $v0                   # $s0 guarda a opcao para o resto do programa

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

    la $a0, var_senha                   # deriva a chave de 16 bits da senha
    jal derivar_chave
    move $a0, $v0
    jal expandir_chave                  # gera as chaves de rodada K0, K1 e K2

    la $a0, var_arquivo_entrada         # abre o arquivo de entrada para leitura
    li $a1, 0
    jal abrir_arquivo
    move $s1, $v0                       # $s1 = fd do arquivo de entrada

    move $a0, $s1                       # le o arquivo de entrada
    la $a1, arq_conteudo_entrada
    li $a2, 1048574                     # deixa 2 bytes de folga para o padding
    jal ler_arquivo
    move $s2, $v0                       # $s2 = bytes lidos

    li $t0, 1
    bne $s0, $t0, principal_decifrar    # opcao 2: descriptografar

    la $a0, arq_conteudo_entrada        # criptografar: acrescenta o padding
    move $a1, $s2
    jal aplicar_padding
    move $s2, $v0                       # $s2 = tamanho com padding (sempre par)

    la $a0, arq_conteudo_entrada        # cifra bloco a bloco
    la $a1, arq_conteudo_saida
    move $a2, $s2
    li $a3, 1
    jal processar_blocos
    j principal_gravar

principal_decifrar:
    andi $t0, $s2, 1                    # arquivo cifrado precisa ter tamanho par
    bnez $t0, principal_invalido
    beqz $s2, principal_invalido        # e nao pode ser vazio

    la $a0, arq_conteudo_entrada        # decifra bloco a bloco
    la $a1, arq_conteudo_saida
    move $a2, $s2
    li $a3, 2
    jal processar_blocos

    la $a0, arq_conteudo_saida          # remove o padding
    move $a1, $s2
    jal remover_padding
    bltz $v0, principal_invalido        # padding invalido: senha errada ou arquivo corrompido
    move $s2, $v0                       # $s2 = tamanho original

principal_gravar:
    la $a0, var_arquivo_saida           # abre o arquivo de saida para escrita
    li $a1, 1
    jal abrir_arquivo
    move $s3, $v0                       # $s3 = fd do arquivo de saida

    move $a0, $s3                       # grava o resultado
    la $a1, arq_conteudo_saida
    move $a2, $s2
    jal escrever_arquivo
    j fim_programa

principal_invalido:
    li $v0, 4
    la $a0, men_arquivo_invalido
    syscall
    j fim_programa

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
    li $v0, 14
    syscall

    move $t0, $v0

    li $v0, 16
    syscall

    move $v0, $t0
    jr $ra

# ----- escrever_arquivo -----
# entrada: $a0 = fd, $a1 = endereco do buffer, $a2 = quantidade de bytes
# saida:   nenhuma
# descricao: grava o buffer no arquivo e fecha o arquivo

escrever_arquivo:
    li $v0, 15
    syscall

    li $v0, 16
    syscall

    jr $ra

# ----- substituir_nibbles -----
# entrada: $a0 = bloco de 16 bits, $a1 = endereco da tabela (sbox ou sbox inversa)
# saida:   $v0 = bloco com cada nibble trocado pelo valor da tabela
# descricao: percorre os 4 nibbles, do mais alto para o mais baixo

substituir_nibbles:
    move $t0, $zero                 # $t0 = bloco resultado
    li $t1, 12                      # $t1 = deslocamento do nibble atual (12, 8, 4, 0)

substituir_laco:
    srlv $t2, $a0, $t1              # leva o nibble atual para os 4 bits mais baixos
    andi $t2, $t2, 0xF              # isola o nibble
    add $t3, $a1, $t2               # endereco da entrada na tabela
    lbu $t3, 0($t3)                 # valor substituido
    sllv $t3, $t3, $t1              # devolve o valor para a posicao do nibble
    or $t0, $t0, $t3                # monta o resultado
    addi $t1, $t1, -4               # proximo nibble
    bgez $t1, substituir_laco
    move $v0, $t0
    jr $ra

# ----- deslocar_linha -----
# entrada: $a0 = bloco de 16 bits (nibbles n0 n1 n2 n3)
# saida:   $v0 = bloco com n1 e n3 trocados (ShiftRow do S-AES)
# descricao: a operacao e a propria inversa, serve para cifrar e decifrar

deslocar_linha:
    andi $t0, $a0, 0xF0F0           # mantem n0 e n2 no lugar
    srl $t1, $a0, 8
    andi $t1, $t1, 0xF              # $t1 = n1
    andi $t2, $a0, 0xF              # $t2 = n3
    sll $t2, $t2, 8                 # n3 vai para a posicao de n1
    or $t0, $t0, $t1                # n1 vai para a posicao de n3
    or $t0, $t0, $t2
    move $v0, $t0
    jr $ra

# ----- multiplicar_gf -----
# entrada: $a0 = fator a (4 bits), $a1 = fator b (4 bits)
# saida:   $v0 = a * b em GF(2^4), polinomio x^4 + x + 1
# descricao: multiplicacao por deslocamento e XOR; altera $a0 e $a1

multiplicar_gf:
    move $t0, $zero                 # $t0 = produto acumulado
    li $t1, 4                       # 4 bits para processar

multiplicar_laco:
    andi $t2, $a1, 1                # bit menos significativo de b
    beqz $t2, multiplicar_sem_soma
    xor $t0, $t0, $a0               # b tem o bit ligado: soma (XOR) a ao produto

multiplicar_sem_soma:
    sll $a0, $a0, 1                 # a = a * x
    andi $t2, $a0, 0x10             # estourou os 4 bits?
    beqz $t2, multiplicar_sem_reducao
    xori $a0, $a0, 0x13             # reduz pelo polinomio x^4 + x + 1 (0x13)

multiplicar_sem_reducao:
    srl $a1, $a1, 1                 # proximo bit de b
    addi $t1, $t1, -1
    bnez $t1, multiplicar_laco

    andi $v0, $t0, 0xF
    jr $ra

# ----- misturar_coluna -----
# entrada: $a0 = nibble de cima, $a1 = nibble de baixo, $a2 = m0, $a3 = m1
# saida:   $v0 = novo nibble de cima, $v1 = novo nibble de baixo
# descricao: multiplica a coluna pela matriz [[m0, m1], [m1, m0]] em GF(2^4)
# registradores salvos: $ra, $s0 a $s4 (guardados na pilha e restaurados no final)

misturar_coluna:
    addi $sp, $sp, -24
    sw $ra, 20($sp)
    sw $s0, 16($sp)
    sw $s1, 12($sp)
    sw $s2, 8($sp)
    sw $s3, 4($sp)
    sw $s4, 0($sp)

    move $s0, $a0                   # $s0 = nibble de cima
    move $s1, $a1                   # $s1 = nibble de baixo
    move $s2, $a2                   # $s2 = m0
    move $s3, $a3                   # $s3 = m1

    move $a0, $s0
    move $a1, $s2
    jal multiplicar_gf              # m0 * cima
    move $s4, $v0
    move $a0, $s1
    move $a1, $s3
    jal multiplicar_gf              # m1 * baixo
    xor $s4, $s4, $v0               # $s4 = novo nibble de cima

    move $a0, $s0
    move $a1, $s3
    jal multiplicar_gf              # m1 * cima
    move $s0, $v0
    move $a0, $s1
    move $a1, $s2
    jal multiplicar_gf              # m0 * baixo
    xor $v1, $s0, $v0               # novo nibble de baixo
    move $v0, $s4

    lw $s4, 0($sp)
    lw $s3, 4($sp)
    lw $s2, 8($sp)
    lw $s1, 12($sp)
    lw $s0, 16($sp)
    lw $ra, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# ----- misturar_colunas -----
# entrada: $a0 = bloco de 16 bits, $a1 = m0, $a2 = m1
# saida:   $v0 = bloco apos o MixColumns
# descricao: aplica o MixColumns nas duas colunas do bloco (nibbles n0 n1 e n2 n3);
#            cifrar usa (m0, m1) = (1, 4) e decifrar usa (9, 2)
# registradores salvos: $ra, $s0 a $s3 (guardados na pilha e restaurados no final)

misturar_colunas:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)
    sw $s3, 0($sp)

    move $s0, $a0                   # $s0 = bloco
    move $s1, $a1                   # $s1 = m0
    move $s2, $a2                   # $s2 = m1

    srl $a0, $s0, 12                # coluna da esquerda: nibbles n0 e n1
    andi $a0, $a0, 0xF
    srl $a1, $s0, 8
    andi $a1, $a1, 0xF
    move $a2, $s1
    move $a3, $s2
    jal misturar_coluna
    sll $s3, $v0, 12
    sll $t0, $v1, 8
    or $s3, $s3, $t0                # $s3 = resultado parcial

    srl $a0, $s0, 4                 # coluna da direita: nibbles n2 e n3
    andi $a0, $a0, 0xF
    andi $a1, $s0, 0xF
    move $a2, $s1
    move $a3, $s2
    jal misturar_coluna
    sll $t0, $v0, 4
    or $s3, $s3, $t0
    or $s3, $s3, $v1

    move $v0, $s3

    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# ----- funcao_g -----
# entrada: $a0 = palavra de 8 bits, $a1 = constante da rodada (RCON)
# saida:   $v0 = palavra transformada
# descricao: troca os dois nibbles de lugar, aplica a S-Box em cada um e faz XOR
#            com a constante; usada na expansao da chave

funcao_g:
    srl $t0, $a0, 4                 # $t0 = nibble alto
    andi $t1, $a0, 0xF              # $t1 = nibble baixo
    la $t2, tabela_sbox

    add $t3, $t2, $t1
    lbu $t3, 0($t3)                 # S-Box do nibble baixo: vira o nibble alto
    add $t4, $t2, $t0
    lbu $t4, 0($t4)                 # S-Box do nibble alto: vira o nibble baixo

    sll $t3, $t3, 4
    or $v0, $t3, $t4
    xor $v0, $v0, $a1
    jr $ra

# ----- expandir_chave -----
# entrada: $a0 = chave de 16 bits
# saida:   chaves_rodada recebe K0, K1 e K2 (uma palavra cada)
# descricao: K0 = chave original, K1 = w2 w3 e K2 = w4 w5, com
#            w2 = w0 XOR g(w1), w3 = w2 XOR w1, w4 = w2 XOR g(w3) e w5 = w4 XOR w3
# registradores salvos: $ra, $s0 a $s2 (guardados na pilha e restaurados no final)

expandir_chave:
    addi $sp, $sp, -16
    sw $ra, 12($sp)
    sw $s0, 8($sp)
    sw $s1, 4($sp)
    sw $s2, 0($sp)

    move $s0, $a0                   # $s0 = chave original (K0)
    la $t0, chaves_rodada
    sw $s0, 0($t0)

    andi $a0, $s0, 0xFF             # w1 = byte baixo da chave
    li $a1, 0x80
    jal funcao_g
    srl $t0, $s0, 8                 # w0 = byte alto da chave
    xor $s1, $t0, $v0               # $s1 = w2 = w0 XOR g(w1)
    andi $t1, $s0, 0xFF
    xor $s2, $s1, $t1               # $s2 = w3 = w2 XOR w1

    sll $t2, $s1, 8
    or $t2, $t2, $s2                # K1 = w2 w3
    la $t0, chaves_rodada
    sw $t2, 4($t0)

    move $a0, $s2
    li $a1, 0x30
    jal funcao_g
    xor $t3, $s1, $v0               # w4 = w2 XOR g(w3)
    xor $t4, $t3, $s2               # w5 = w4 XOR w3
    sll $t3, $t3, 8
    or $t3, $t3, $t4                # K2 = w4 w5
    la $t0, chaves_rodada
    sw $t3, 8($t0)

    lw $s2, 0($sp)
    lw $s1, 4($sp)
    lw $s0, 8($sp)
    lw $ra, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# ----- cifrar_bloco -----
# entrada: $a0 = bloco de 16 bits (texto claro); expandir_chave ja deve ter sido chamada
# saida:   $v0 = bloco cifrado
# descricao: AddRoundKey (K0); rodada 1 (S-Box, ShiftRow, MixColumns, K1);
#            rodada 2 (S-Box, ShiftRow, K2)
# registradores salvos: $ra (guardado na pilha e restaurado no final)

cifrar_bloco:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $t0, chaves_rodada
    lw $t1, 0($t0)
    xor $a0, $a0, $t1               # AddRoundKey com K0

    la $a1, tabela_sbox             # rodada 1
    jal substituir_nibbles
    move $a0, $v0
    jal deslocar_linha
    move $a0, $v0
    li $a1, 1
    li $a2, 4
    jal misturar_colunas
    la $t0, chaves_rodada
    lw $t1, 4($t0)
    xor $a0, $v0, $t1               # AddRoundKey com K1

    la $a1, tabela_sbox             # rodada 2 (sem MixColumns)
    jal substituir_nibbles
    move $a0, $v0
    jal deslocar_linha
    la $t0, chaves_rodada
    lw $t1, 8($t0)
    xor $v0, $v0, $t1               # AddRoundKey com K2

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----- decifrar_bloco -----
# entrada: $a0 = bloco de 16 bits (cifrado); expandir_chave ja deve ter sido chamada
# saida:   $v0 = bloco decifrado
# descricao: operacoes inversas na ordem contraria: K2; ShiftRow e S-Box inversa;
#            K1; MixColumns inverso; ShiftRow e S-Box inversa; K0
# registradores salvos: $ra (guardado na pilha e restaurado no final)

decifrar_bloco:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    la $t0, chaves_rodada
    lw $t1, 8($t0)
    xor $a0, $a0, $t1               # AddRoundKey com K2

    jal deslocar_linha              # rodada 2 inversa
    move $a0, $v0
    la $a1, tabela_sbox_inversa
    jal substituir_nibbles
    la $t0, chaves_rodada
    lw $t1, 4($t0)
    xor $a0, $v0, $t1               # AddRoundKey com K1

    li $a1, 9                       # MixColumns inverso
    li $a2, 2
    jal misturar_colunas

    move $a0, $v0                   # rodada 1 inversa
    jal deslocar_linha
    move $a0, $v0
    la $a1, tabela_sbox_inversa
    jal substituir_nibbles
    la $t0, chaves_rodada
    lw $t1, 0($t0)
    xor $v0, $v0, $t1               # AddRoundKey com K0

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# ----- derivar_chave -----
# entrada: $a0 = endereco da senha (terminada em \0)
# saida:   $v0 = chave de 16 bits
# descricao: caracteres de posicao par entram por XOR no byte alto da chave
#            e os de posicao impar, no byte baixo

derivar_chave:
    move $t0, $zero                 # $t0 = byte alto
    move $t1, $zero                 # $t1 = byte baixo

derivar_laco:
    lbu $t2, 0($a0)                 # caractere de posicao par
    beqz $t2, derivar_fim
    xor $t0, $t0, $t2
    addi $a0, $a0, 1

    lbu $t2, 0($a0)                 # caractere de posicao impar
    beqz $t2, derivar_fim
    xor $t1, $t1, $t2
    addi $a0, $a0, 1
    j derivar_laco

derivar_fim:
    sll $t0, $t0, 8
    or $v0, $t0, $t1
    jr $ra

# ----- aplicar_padding -----
# entrada: $a0 = endereco do buffer, $a1 = tamanho dos dados
# saida:   $v0 = novo tamanho (sempre par)
# descricao: tamanho impar recebe o byte 0x01; tamanho par recebe 0x02 0x02

aplicar_padding:
    add $t0, $a0, $a1               # $t0 = endereco logo apos o ultimo byte
    andi $t1, $a1, 1
    beqz $t1, padding_par

    li $t2, 1                       # tamanho impar: falta 1 byte
    sb $t2, 0($t0)
    addi $v0, $a1, 1
    jr $ra

padding_par:
    li $t2, 2                       # tamanho par: acrescenta um bloco inteiro
    sb $t2, 0($t0)
    sb $t2, 1($t0)
    addi $v0, $a1, 2
    jr $ra

# ----- remover_padding -----
# entrada: $a0 = endereco do buffer decifrado, $a1 = tamanho (par, maior que 0)
# saida:   $v0 = tamanho sem o padding, ou -1 se o padding for invalido
# descricao: um padding invalido indica senha incorreta ou arquivo corrompido

remover_padding:
    add $t0, $a0, $a1               # $t0 = endereco logo apos o ultimo byte
    lbu $t1, -1($t0)                # ultimo byte indica o padding
    li $t2, 1
    beq $t1, $t2, remover_um
    li $t2, 2
    bne $t1, $t2, remover_invalido
    lbu $t3, -2($t0)                # padding de 2 bytes: o penultimo tambem vale 2
    bne $t3, $t2, remover_invalido
    addi $v0, $a1, -2
    jr $ra

remover_um:
    addi $v0, $a1, -1
    jr $ra

remover_invalido:
    li $v0, -1
    jr $ra

# ----- processar_blocos -----
# entrada: $a0 = buffer de entrada, $a1 = buffer de saida, $a2 = tamanho (par),
#          $a3 = modo (1 = cifrar, 2 = decifrar)
# saida:   buffer de saida preenchido
# descricao: percorre o buffer de 2 em 2 bytes (modo ECB); o primeiro byte
#            do bloco e o byte alto
# registradores salvos: $ra, $s0 a $s3 (guardados na pilha e restaurados no final)

processar_blocos:
    addi $sp, $sp, -20
    sw $ra, 16($sp)
    sw $s0, 12($sp)
    sw $s1, 8($sp)
    sw $s2, 4($sp)
    sw $s3, 0($sp)

    move $s0, $a0                   # $s0 = ponteiro de entrada
    move $s1, $a1                   # $s1 = ponteiro de saida
    add $s2, $a0, $a2               # $s2 = endereco final da entrada
    move $s3, $a3                   # $s3 = modo

processar_laco:
    bge $s0, $s2, processar_fim
    lbu $t0, 0($s0)                 # byte alto do bloco
    lbu $t1, 1($s0)                 # byte baixo do bloco
    sll $t0, $t0, 8
    or $a0, $t0, $t1                # $a0 = bloco de 16 bits

    li $t2, 1
    beq $s3, $t2, processar_cifrar
    jal decifrar_bloco
    j processar_gravar

processar_cifrar:
    jal cifrar_bloco

processar_gravar:
    srl $t0, $v0, 8
    sb $t0, 0($s1)                  # grava o byte alto
    sb $v0, 1($s1)                  # grava o byte baixo
    addi $s0, $s0, 2
    addi $s1, $s1, 2
    j processar_laco

processar_fim:
    lw $s3, 0($sp)
    lw $s2, 4($sp)
    lw $s1, 8($sp)
    lw $s0, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra