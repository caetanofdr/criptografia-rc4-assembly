# Criptografia de arquivos com RC4 em assembly MIPS

Programa em assembly MIPS, executado no simulador [MARS](https://dpetersanderson.github.io/), que criptografa e descriptografa arquivos usando a cifra de fluxo **RC4** a partir de uma senha digitada pelo usuário.

Trabalho 1 da disciplina **ELC1011 – Organização de Computadores** da Universidade Federal de Santa Maria (UFSM), semestre 2026/2, ministrada pelo prof. Giovani Baratto.

> [!WARNING]
> O RC4 tem fraquezas conhecidas e é proibido no TLS desde a [RFC 7465](https://www.rfc-editor.org/rfc/rfc7465). Este projeto tem finalidade **apenas didática** e não deve ser usado para proteger dados reais.

## Sobre o trabalho

A proposta da disciplina era desenvolver, em assembly MIPS para o simulador MARS, um programa de terminal que criptografasse e descriptografasse arquivos de texto. O trabalho podia ser feito individualmente ou em dupla, e o programa deveria:

- perguntar se o usuário quer criptografar ou descriptografar um arquivo;
- pedir o nome do arquivo de entrada e o nome do arquivo de saída;
- pedir uma senha, usada como chave da cifra;
- gravar o resultado no arquivo de saída.

Cada equipe implementava apenas um algoritmo: **RC4** ou **S-AES** (*Simplified AES*). A escolha seguia uma regra: somavam-se os dois últimos dígitos da matrícula de cada integrante; soma par levava ao RC4 e soma ímpar ao S-AES. A soma da nossa dupla foi par, por isso este repositório implementa o RC4.

Para validar o programa, era preciso cifrar dois arquivos de texto com a chave `ELC1011`, decifrá-los em seguida e conferir se o conteúdo voltava idêntico ao original.

## Funcionalidades

- Menu no terminal com as opções **1 – Criptografar** e **2 – Descriptografar**.
- Leitura dos nomes dos arquivos de entrada e de saída e da senha.
- Implementação das duas fases do RC4: **KSA** (*Key Scheduling Algorithm*) e **PRGA** (*Pseudo-Random Generation Algorithm*).
- Uma única rotina para cifrar e decifrar, já que o RC4 aplica um XOR com a sequência gerada pela chave ($C = P \oplus K$ e $P = C \oplus K$).
- Tratamento de entradas inválidas: opção de menu diferente de `1` ou `2`, nomes ou senha vazios e arquivo de entrada inexistente.

## Como o RC4 funciona

O estado do RC4 é um vetor $S$ de 256 bytes e dois índices, $i$ e $j$, com todas as somas feitas módulo 256.

1. **KSA:** $S[i] = i$ para $i$ de 0 a 255. Depois, para cada $i$ de 0 a 255, faz-se $j = j + S[i] + \text{chave}[i \bmod n]$ e troca-se $S[i]$ com $S[j]$, onde $n$ é o tamanho da chave.
2. **PRGA:** para cada byte da entrada, faz-se $i = i + 1$, $j = j + S[i]$, troca-se $S[i]$ com $S[j]$ e usa-se $K = S[S[i] + S[j]]$ como byte da sequência. O byte de saída é o byte de entrada XOR $K$.

## Estrutura do repositório

```
.
├── relatorio/
│   └── relatorio.pdf # relatório do trabalho
├── source/
│   └── main.asm      # programa completo (menu, arquivos e RC4)
├── .gitignore
└── README.md
```

O `main.asm` é organizado em sub-rotinas chamadas em sequência pelo `main`:

| Sub-rotina         | Função                                                              |
| ------------------ | ------------------------------------------------------------------- |
| `mostrar_menu`     | Mostra o menu e repete até receber uma opção válida                 |
| `pedir_texto`      | Lê um texto do teclado, remove o `\n` e repete se vier vazio        |
| `tirar_barra_n`    | Troca o primeiro `\n` de um texto por `\0`                          |
| `inicializar_rc4`  | Executa o KSA, montando o vetor $S$ a partir da senha               |
| `abrir_arquivo`    | Abre um arquivo para leitura ou escrita; encerra se falhar          |
| `ler_arquivo`      | Lê o arquivo de entrada para um buffer de 1 MB e o fecha            |
| `processar_rc4`    | Executa o PRGA e aplica o XOR byte a byte                           |
| `escrever_arquivo` | Grava o resultado no arquivo de saída e o fecha                     |

## Como executar

### Requisitos

- Java instalado.
- [MARS 4.5](https://dpetersanderson.github.io/) (arquivo `Mars4_5.jar`).

### Pela interface do MARS

1. Abra o MARS e carregue `source/main.asm` (*File → Open*).
2. Monte o programa (*Run → Assemble*, ou `F3`).
3. Execute (*Run → Go*, ou `F5`) e interaja pelo painel *Run I/O*.

### Pelo terminal

```bash
java -jar Mars4_5.jar nc source/main.asm
```

> [!NOTE]
> Os nomes de arquivo são resolvidos a partir do diretório em que o MARS foi iniciado. Se o programa mostrar `Arquivo nao encontrado`, use o caminho completo do arquivo ou inicie o MARS na mesma pasta dos arquivos.

### Exemplo de uso

```
Bem-vindo! Selecione uma opcao:
1 - Criptografar arquivo
2 - Descriptografar arquivo
Sua escolha: 1
Voce escolheu criptografar
Digite o nome do arquivo de entrada: texto1.txt
Digite o nome do arquivo de saida: secreto1.rc4
Digite a senha: ELC1011
```

Para recuperar o original, execute de novo escolhendo a opção `2`, informando `secreto1.rc4` como entrada e a mesma senha.

## Testes

As saídas do programa foram comparadas byte a byte com as de uma implementação de referência em C++ escrita a partir do mesmo algoritmo.

| Senha     | Texto claro      | Saída (hexadecimal)                            |
| --------- | ---------------- | ---------------------------------------------- |
| `Key`     | `Plaintext`      | `BB F3 16 E8 D9 40 AF 0A D3`                   |
| `ELC1011` | `Assembly MIPS`  | `D6 8D 83 B5 49 98 54 2A 4C 18 1C EE 63`       |
| `Secret`  | `Attack at dawn` | `45 A0 1F 64 5F C3 5B 38 35 52 54 4B 9B F5`    |

Também foi feito o teste de ida e volta pedido no enunciado: dois arquivos de texto (139 bytes, com acentos, e 37.789 bytes) foram cifrados com a chave `ELC1011` e depois decifrados, ficando idênticos aos originais. A comparação com a referência em C++ também foi feita com um arquivo de 1 MB, sem diferenças.

Segundo o contador do MARS, o programa executa cerca de **21 instruções por byte** processado, então o tempo cresce linearmente com o tamanho do arquivo.

## Limitações

- Arquivos maiores que **1 MB**: apenas o primeiro 1 MB é processado, sem aviso.
- Senha com no máximo **63 caracteres**.
- Não há verificação de erros de leitura e escrita depois que os arquivos são abertos.
- Características do próprio RC4, e não do programa:
  - senha errada não gera erro, apenas produz um arquivo ilegível;
  - senhas como `ab` e `abab` são equivalentes, porque o KSA repete a chave até completar 256 posições.

## Relatório

O [relatório do trabalho](relatorio/relatorio.pdf) traz o referencial teórico, a metodologia, os experimentos e a discussão dos resultados, além da implementação de referência em C++ usada nos testes.

## Autores

- Andrei Ribeiro
- Caetano Facco da Rosa

## Referências

- BARATTO, G. *ELC1011 – Trabalho 1: Criptografia RC4 ou AES-S*. Santa Maria: UFSM, 2026.
- PATTERSON, D. A.; HENNESSY, J. L. *Organização e projeto de computadores: a interface hardware/software*. 4. ed. Rio de Janeiro: Elsevier, 2014.
- POPOV, A. *RFC 7465: Prohibiting RC4 cipher suites*. IETF, 2015.
- SCHNEIER, B. *Applied cryptography: protocols, algorithms, and source code in C*. 2. ed. New York: Wiley, 1996.
- VOLLMAR, K.; SANDERSON, P. MARS: an education-oriented MIPS assembly language simulator. *ACM SIGCSE Bulletin*, v. 38, n. 1, p. 239–243, 2006.
