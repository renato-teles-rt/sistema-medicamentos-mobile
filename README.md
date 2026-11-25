# CuidaMed 50+ (cuidamed_mobile)

Aplicativo **Flutter/Dart** para acompanhamento de medicações de pacientes 50+,
com controle de estoque e alertas de reposição. O app conversa com um backend
**Java + Spring Boot** (autenticação Google, vínculo familiar e catálogo de
medicamentos por paciente).

> Este README foi escrito para servir de **embasamento técnico do projeto**: o que
> existe hoje, o que o backend precisa entregar, e os pontos que costumam gerar
> erro ao rodar/depurar Flutter + Spring Boot juntos.

---

## 1. Visão geral

| Camada | Tecnologia | Responsabilidade |
| --- | --- | --- |
| Mobile | Flutter 3.x / Dart 3.11+ | UI, sessão local, catálogo offline (SharedPreferences) |
| Backend | Java 17+ / Spring Boot 3.5 | Login Google, usuários, vínculo paciente↔cuidador, API de medicamentos |

O app foi desenhado para **funcionar sem back-end** (dados locais + sessão em
`SharedPreferences`). As chamadas HTTP têm `try/catch` que caem no modo offline
em vez de travar a tela — por isso, quando "nada sincroniza", geralmente o erro é
de configuração de rede, não de lógica.

---

## 2. Estrutura do projeto

```
lib/
├── main.dart                      # Bootstrap: carrega sessão e escolhe a tela inicial
├── config/
│   └── api_config.dart            # Base URL por plataforma + --dart-define=API_BASE_URL
├── models/
│   ├── medicamento_model.dart     # Item do catálogo + cálculo de estoque (diasRestantes/statusEstoque)
│   ├── usuario_model.dart         # Usuário autenticado (id, nome, email, tipoPerfil, codigoVinculo)
│   └── vinculo_familiar_model.dart# Vínculo paciente ↔ cuidador
├── services/
│   ├── auth_vinculo_service.dart  # Google Sign-In + endpoints /api/auth/*
│   ├── session_service.dart       # Sessão local + headers autenticados (X-Usuario-Id)
│   └── medicamento_service.dart   # CRUD local por paciente + sincronização com a API
├── theme/app_theme.dart           # Tema único (Material 3, acessibilidade)
└── views/
    ├── login_view.dart            # Login com Google
    ├── escolha_cuidador_view.dart # Escolha do tipo de perfil
    ├── home_paciente_view.dart    # Catálogo de medicações, busca, estoque, reposição
    └── painel_vinculo_view.dart   # Código de vínculo, cuidadores/pacientes, desvincular

backend/                           # Spring Boot (Java 17+)
├── mvnw / mvnw.cmd                # Maven Wrapper (não exige Maven instalado)
├── pom.xml
└── src/main/java/br/com/cuidamed/
    ├── CuidaMedApplication.java
    ├── config/CorsConfig.java                # CORS para o build web do Flutter
    ├── controller/AuthController.java        # /api/auth/*
    ├── controller/MedicamentoController.java # /api/medicamentos/*
    ├── domain/                               # Usuario, VinculoFamiliar, Medicamento, enums
    ├── dto/                                  # JSON idêntico ao fromJson() do app
    ├── exception/                            # Erros no formato { "erro": "..." }
    ├── repository/                           # Spring Data JPA
    └── service/                              # AuthService, VinculoService, MedicamentoService, CalculoEstoque

test/
├── medicamento_service_test.dart  # Persistência/ordenação/isolamento por paciente
├── home_catalogo_widget_test.dart # Teste de widget do catálogo
├── verificar_estoque_test.dart    # Regras de negócio de estoque
├── protecao_storage_test.dart     # Storage corrompido não derruba o bootstrap
└── widget_test.dart               # Smoke test da tela inicial
tool/
├── servir_web.ps1                 # Serve build/web em 127.0.0.1:5173
├── verificar_estoque.dart         # Script de sanidade das regras de estoque (sem emulador)
└── verificar_service.dart         # Script de sanidade do MedicamentoService
```

### Fluxo de navegação

```
main.dart
  └── sessão salva? --não--> LoginView (Google)
                        └--> tipoPerfil == 'PACIENTE' ? HomePacienteView : PainelVinculoView
```

---

## 3. Regras de negócio implementadas

### 3.1 Estoque (`MedicamentoModel`)

- `consumoDiario` = `quantidadePorDose` (quantas unidades cada dose consome).
- `diasRestantes` = `quantidadeTotal ~/ consumoDiario` (divisão inteira, nunca negativa).
- `statusEstoque`:
  - `esgotado` → `quantidadeTotal <= 0`
  - `baixo` → `diasRestantes <= diasAlerta` (padrão **3 dias**)
  - `normal` → caso contrário
- `mensagemStatus` monta o texto do alerta exibido na UI.

### 3.2 Catálogo local (`MedicamentoService`)

- Chave de persistência: `cuidamed_medicamentos_<pacienteId>` → cada paciente tem
  catálogo isolado no mesmo dispositivo.
- Lista sempre gravada **ordenada por nome** (case-insensitive).
- JSON corrompido não trava a tela: `listar()` devolve lista vazia.
- `sincronizar(pacienteId)` busca `GET /api/medicamentos/paciente/{id}`; em caso de
  falha de rede mantém o catálogo local.

### 3.3 Sessão e vínculo

- Sessão salva em `cuidamed_usuario_sessao` (`SessionService`).
- Todas as requisições autenticadas enviam o header `X-Usuario-Id`.
- Regra **RN01**: um paciente tem no máximo **2 cuidadores ativos**. A validação
  é feita no **backend** (`VinculoService`); o painel apenas exibe o contador e
  oferece o botão de desvincular para liberar vaga.
- Regra **RN03**: um cuidador só pode vincular a própria conta — o
  `cuidadorId` do corpo precisa bater com o `X-Usuario-Id`.

### 3.4 Autorização (backend)

| Perfil | Lê catálogo | Escreve catálogo | Vincula | Desvincula |
| --- | --- | --- | --- | --- |
| Paciente | o próprio | sim | — | os próprios vínculos |
| Cuidador vinculado | sim | **não** | a si mesmo | os próprios vínculos |
| Cuidador sem vínculo | não (401) | não (401) | a si mesmo | não (401) |

### 3.5 Proteção do armazenamento local

Um valor com **tipo inesperado** em `SharedPreferences` (por exemplo um Map
 onde o plugin espera String) fazia `getString` lançar `TypeError` **antes** de
qualquer `try/catch` de parse. Como isso acontecia dentro de `main()`, o app
subia em **tela branca**, sem mensagem. Três camadas impedem a recorrência:

1. `main()` envolve a restauração da sessão em `try/catch` e cai no login.
2. `SessionService._lerString` lê com `prefs.get` e descarta valores de tipo
   errado; a sessão também é rejeitada se faltar `id` ou `email`.
3. `MedicamentoService.listar` trata a exceção de tipo e valida que o JSON
   decodificado é uma `List`.

Cobertura: `test/protecao_storage_test.dart` (6 cenários, incluindo o widget
subindo no login com storage corrompido).

---

## 4. Contrato com o back-end (Spring Boot)

O backend **existe neste repositório** (`backend/`) e implementa todas as rotas
abaixo. A base URL não está mais fixa no código: vem de
`lib/config/api_config.dart`, que aceita
`--dart-define=API_BASE_URL=...` e tem padrão por plataforma
(`localhost` na web, `10.0.2.2` no emulador Android).

### 4.1 Autenticação — `/api/auth`

| Método | Rota | Body | Resposta esperada |
| --- | --- | --- | --- |
| POST | `/google-token` | `{ "idToken": "...", "tipoPerfil": "PACIENTE" \| "CUIDADOR" }` | `200` + `UsuarioResponse` |
| POST | `/vincular` | `{ "cuidadorId": 1, "codigoVinculo": "ABC123" }` | `200` |
| GET | `/paciente/{pacienteId}/cuidadores` | — | `200` + `List<VinculoFamiliar>` |
| GET | `/cuidador/{cuidadorId}/pacientes` | — | `200` + `List<VinculoFamiliar>` |
| DELETE | `/vincular/{vinculoId}` | — | `200` |

`UsuarioResponse` (JSON em camelCase):

```json
{
  "id": 1,
  "nome": "Maria Silva",
  "email": "maria@email.com",
  "fotoUrl": "https://...",
  "tipoPerfil": "PACIENTE",
  "codigoVinculo": "ABC123"
}
```

`VinculoFamiliar`:

```json
{
  "id": 10,
  "paciente": { "...UsuarioResponse" },
  "cuidador": { "...UsuarioResponse" },
  "ativo": true
}
```

Erros devem vir como `{ "erro": "mensagem amigável" }` com status `4xx/5xx` —
o app usa esse campo para exibir o texto ao usuário.

### 4.2 Medicamentos — `/api/medicamentos`

Todas as rotas exigem o header `X-Usuario-Id`.

| Método | Rota | Observação |
| --- | --- | --- |
| GET | `/paciente/{pacienteId}` | Lista usada por `sincronizar()`, ordenada por nome |
| GET | `/paciente/{pacienteId}/{medicamentoId}` | Item individual |
| POST | `/paciente/{pacienteId}` | Cria (201). O `id` pode vir no corpo |
| PUT | `/paciente/{pacienteId}/{medicamentoId}` | Edita |
| POST | `/paciente/{pacienteId}/{medicamentoId}/repor` | Body `{ "quantidade": 30 }` — soma |
| POST | `/paciente/{pacienteId}/{medicamentoId}/dose` | Registra dose tomada (trava em 0) |
| DELETE | `/paciente/{pacienteId}/{medicamentoId}` | Remove |

Campos do medicamento no JSON (mesmos nomes de `toJson()`):

```json
{
  "id": "1",
  "nome": "Losartana",
  "dosagem": "50mg",
  "horario": "08:00",
  "quantidadePorDose": 1,
  "quantidadeTotal": 30,
  "diasAlerta": 3,
  "observacao": ""
}
```

A resposta inclui ainda `diasRestantes` e `statusEstoque` (`NORMAL` / `BAIXO` /
`ESGOTADO`), calculados pelo backend com a **mesma** regra do app
(`CalculoEstoque` em Java ↔ `medicamento_model.dart` em Dart). São informativos:
 o app ignora campos desconhecidos e recalcula localmente.

### 4.3 Estrutura do backend implementado

Os controllers de referência do README original já foram implementados em
`backend/src/main/java/br/com/cuidamed/` — não há mais esboço a copiar:

| Arquivo | Papel |
| --- | --- |
| `controller/AuthController.java` | `/google-token`, `/vincular`, listagens e `DELETE` |
| `controller/MedicamentoController.java` | CRUD, `/repor` e `/dose` |
| `service/VinculoService.java` | RN01 (limite 2), RN03, reativação de vínculo |
| `service/MedicamentoService.java` | autorização leitura/escrita, RN05 (duplicidade) |
| `service/CalculoEstoque.java` | espelho de `medicamento_model.dart` |
| `service/GoogleTokenVerifier.java` | validação do ID token (+ modo dev) |
| `exception/GlobalExceptionHandler.java` | tudo vira `{ "erro": "..." }` |

Configuração (`backend/src/main/resources/application.yml`), com banco em arquivo
para persistir entre reinicializações:

```yaml
server:
  port: 8080
  address: 0.0.0.0        # o celular precisa alcançar o PC

spring:
  datasource:
    url: jdbc:h2:file:./data/cuidamed;AUTO_SERVER=TRUE;DB_CLOSE_DELAY=-1
    username: sa
    password: ""
  jpa:
    hibernate:
      ddl-auto: update    # dev; produção: migrations + validate

cuidamed:
  google:
    client-id: ${GOOGLE_CLIENT_ID:}   # vazio = modo dev
  vinculo:
    max-cuidadores-por-paciente: 2    # RN01
```

Console do H2 (inspeção em dev): `http://localhost:8080/h2-console`
(JDBC URL `jdbc:h2:file:./data/cuidamed`, usuário `sa`, senha vazia).

---

## 5. Como rodar o projeto

### 5.1 Pré-requisitos

| Item | Versão mínima | Por quê |
| --- | --- | --- |
| Flutter | **3.x** (Dart 3.11+) | `pubspec.yaml` declara `sdk: ^3.11.0` |
| JDK | **17+** | Spring Boot 3.5 (testado com o JDK 25 LTS) |
| Maven | **não necessário** | o projeto inclui `backend/mvnw` (Maven Wrapper) |
| Android Studio / Xcode | — | Emulador/simulador |

Verifique as versões:

```powershell
flutter --version
dart --version
java -version
```

> **Erro comum:** `Because cuidamed_mobile requires SDK version ^3.11.0, version
> solving failed`. O Flutter/Dart instalado é mais antigo que o exigido pelo
> `pubspec.yaml`. Atualize com `flutter upgrade` — **não** altere o `pubspec.yaml`
> para contornar.

### 5.2 Mobile

```powershell
flutter pub get
flutter analyze
flutter test                       # 14 testes
dart run tool/verificar_estoque.dart
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

> `tool/verificar_service.dart` **não roda** com `dart run`: ele usa
> `shared_preferences`, que depende do engine do Flutter (`dart:ui`). O mesmo
> comportamento já é coberto por `flutter test test/medicamento_service_test.dart`.

### 5.3 Backend

O `JAVA_HOME` precisa apontar para um JDK 17+ (o `java` do PATH pode ser o 8).

```powershell
cd backend
$env:JAVA_HOME="C:\caminho\para\o\jdk"   # PowerShell
.\mvnw.cmd spring-boot:run
```

Sobe em `http://0.0.0.0:8080` (necessário para o celular na mesma rede Wi-Fi —
escutar só em localhost causa `Connection refused` no aparelho).

Testes do backend:

```powershell
cd backend
.\mvnw.cmd test                    # 25 testes (contrato HTTP + regras + login)
```

Os testes usam **H2 em memória** (`src/test/resources/application-test.yml`) e
não tocam o banco de desenvolvimento (`backend/data/cuidamed`).

### 5.4 Rodar tudo junto

```powershell
# terminal 1 — backend
cd backend; .\mvnw.cmd spring-boot:run

# terminal 2 — app web apontando para o backend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

No celular físico, use o IP do PC: `--dart-define=API_BASE_URL=http://192.168.0.5:8080`.

### 5.5 Login sem Google (desenvolvimento)

Com `GOOGLE_CLIENT_ID` vazio o backend aceita qualquer `idToken` e usa o próprio
token como identidade (`<token>@cuidamed.local`). Isso permite criar quantos
usuários quiser para testar:

```powershell
# paciente
curl -X POST http://localhost:8080/api/auth/google-token -H "Content-Type: application/json" -d '{"idToken":"dev-paciente","tipoPerfil":"PACIENTE"}'
# cuidador
curl -X POST http://localhost:8080/api/auth/google-token -H "Content-Type: application/json" -d '{"idToken":"dev-cuidador","tipoPerfil":"CUIDADOR"}'
```

**Nunca use assim em produção** — defina `GOOGLE_CLIENT_ID` para ativar a
validação real do token.

---

## 6. Erros que já apareceram e como resolver (checklist)

Esta seção existe para evitar retrabalho — cada item já foi causa real de falha.

| Sintoma | Causa | Solução |
| --- | --- | --- |
| `version solving failed` / "requires SDK version" | Flutter/Dart antigo para `sdk: ^3.11.0` | `flutter upgrade`; confirme `dart --version` ≥ 3.11 |
| App "não salva nada" ou volta vazio | Falha silenciosa na API (catch ignora rede) | Verifique `flutter logs`; teste `GET` no navegador do celular |
| Login Google trava no emulador | `serverClientId` precisa bater com o OAuth client **tipo Web** do backend | Mesmo `client_id` no `GoogleSignIn` e em `GOOGLE_CLIENT_ID` no Spring |
| `PlatformException(sign_in_failed, ApiException: 10)` | SHA-1 do certificado do app não cadastrado | Cadastre a SHA-1 de debug/release no console OAuth do Google |
| Tela branca no Android ao chamar API | Cleartext HTTP bloqueado | Já resolvido com `android:usesCleartextTraffic="true"`; em produção use **HTTPS** |
| `Connection refused` / timeout | Backend escutando só em `localhost` | `server.address=0.0.0.0` + libere a porta 8080 no firewall do Windows |
| **Tela branca sem mensagem ao abrir** | Valor com tipo errado em `SharedPreferences` estourava dentro de `main()` | Protegido por 3 camadas (README §3.5); ver `test/protecao_storage_test.dart` |
| `401` ao listar cuidadores | `X-Usuario-Id` ausente (sessão não restaurada) | Confira `SessionService.obterSessaoAtiva()` antes das chamadas |
| `401 Sessao invalida` | Sessão salva aponta para um usuário que não existe no backend | Banco de dev foi recriado; faça login de novo |
| `401 Esta conta ja esta cadastrada como PACIENTE` | Mesmo e-mail tentando entrar com outro perfil | Use o perfil original; a troca é bloqueada de propósito |
| `404` em `/api/medicamentos/...` | Backend não está rodando | Suba o `backend/` (§5.3) — o app cai no modo offline |
| JSON com `null` em `fromJson` | Campo obrigatório ausente ou tipo errado | Backend sempre envia `id`, `nome`, `email`, `tipoPerfil`, `codigoVinculo` |
| Texto grande "estourando" layout | Acessibilidade 50+ | `main.dart` limita `textScaler` a 1.35; não remova esse clamp |
| `flutter pub run` deprecado | Flutter novo trocou por `dart run` | Use `dart run tool/verificar_estoque.dart` |
| `dart run tool/verificar_service.dart` falha com `dart:ui is not available` | O script usa `shared_preferences`, que exige o engine do Flutter | Rode `flutter test test/medicamento_service_test.dart` em vez dele |
| `mvnw.cmd : não é reconhecido...` | PowerShell não executa no diretório atual implicitamente | Use `.\mvnw.cmd` ou `cmd /c ".\mvnw.cmd spring-boot:run"` |
| `java -version` mostra 1.8 | JDK antigo no PATH | Defina `$env:JAVA_HOME` para um JDK 17+ antes de rodar o Maven |

---

## 7. Convenções do projeto

- **UI em português**, strings acentuadas nos testes de widget (`find.text(...)`).
- **Camada service sempre assíncrona** — trocar local por HTTP não deve mudar a
  assinatura pública.
- **Falha de rede nunca deve quebrar a tela**: fallback local + mensagem amigável.
- **Tipos tolerantes no `fromJson`**: números podem vir como `"1"` ou `1`
  (`_paraInteiro`); o backend deve, ainda assim, padronizar tipos numéricos.
- **Acessibilidade**: fontes ≥ 16, `tooltip` em todos os ícones, foco visual claro
  (`app_theme.dart`).
- **Nada de segredo no repositório**: `client-id`, senhas e tokens em variáveis de
  ambiente (`.env`, `application-prod.yml`) fora do Git.

---

## 8. Roadmap sugerido

1. Trocar `MedicamentoService` de local para HTTP nas **escritas** (hoje só a
   leitura sincroniza; criar/editar/repor/remover ainda são locais).
   Os endpoints já existem em `MedicamentoController`.
2. Trocar `X-Usuario-Id` por JWT assinado — hoje o header é confiado ao cliente
   (ver limitação abaixo).
3. Adicionar migrations (Flyway) e trocar `ddl-auto: update` por `validate`.
4. Persistir notificações de estoque baixo (`flutter_local_notifications`).
5. Migrar `SharedPreferences` para armazenamento criptografado (dados de saúde).
6. Dar ao cuidador uma tela de leitura do catálogo do paciente (o backend já
   autoriza; falta a UI).

### Limitações conscientes do backend atual

- **`X-Usuario-Id` não é assinado.** Qualquer cliente pode enviar outro id. É
  aceitável para o MVP em rede local; em produção troque por JWT/Spring Security.
  As regras de autorização (quem pode o quê) já estão implementadas — só a
  *identidade* do chamador é que não é garantida.
- **Login dev sem `GOOGLE_CLIENT_ID`** aceita qualquer token. Use apenas local.
- **CORS aberto** (`*`) para desenvolvimento; restrinja em produção.
- **HTTP sem TLS** — em produção sirva por HTTPS (e remova
  `usesCleartextTraffic` do Android).

---

## 9. Referências

- [Flutter — Documentação oficial](https://docs.flutter.dev/)
- [Dart — Guia da linguagem](https://dart.dev/language)
- [Spring Boot — Referência](https://docs.spring.io/spring-boot/reference/)
- [Spring Security — Validação de ID token do Google](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)
- [Google Sign-In para Flutter](https://pub.dev/packages/google_sign_in)
- [http (pacote Dart)](https://pub.dev/packages/http)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
