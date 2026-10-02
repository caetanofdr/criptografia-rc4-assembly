.data
menu:
    .ascii  "Bem-vindo! Selecione uma opcao:\n"
    .ascii  "1 - Criptografar arquivo\n"
    .ascii  "2 - Descriptografar arquivo\n"
    .asciiz "Sua escolha: "
mensagem_criptografar:
    .asciiz "Voce escolheu criptografar\n"
mensagem_descriptografar:
    .asciiz "Voce escolheu descriptografar\n"
mensagem_invalida:
    .asciiz "Opcao invalida\n"

.text
principal:
    li $v0, 4                       # syscall 4: imprimir string
    la $a0, menu                    # $a0 recebe o endereco do menu
    syscall                         # imprime o menu completo

    li $v0, 5                       # syscall 5: ler inteiro do teclado
    syscall                         # o numero lido volta em $v0
    move $s0, $v0                   # guarda a opcao em $s0

    li $t0, 1                       # $t0 = 1
    beq $s0, $t0, criptografar      # se a opcao for 1, vai para criptografar
    li $t0, 2                       # $t0 = 2
    beq $s0, $t0, descriptografar   # se a opcao for 2, vai para descriptografar

    li $v0, 4                       # nenhuma opcao valida: imprime o aviso
    la $a0, mensagem_invalida
    syscall
    j principal                     # volta ao inicio e mostra o menu de novo

criptografar:
    li $v0, 4                       # imprime a mensagem da opcao 1
    la $a0, mensagem_criptografar
    syscall
    j encerrar                      # pula o ramo de descriptografar

descriptografar:
    li $v0, 4                       # imprime a mensagem da opcao 2
    la $a0, mensagem_descriptografar
    syscall

encerrar:
    li $v0, 10                      # syscall 10: encerrar o programa
    syscall