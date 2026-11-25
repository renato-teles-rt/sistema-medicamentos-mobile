# backend — CuidaMed 50+

Backend Java 17+ / Spring Boot 3.5 do CuidaMed. Implementa autenticação Google,
vínculo paciente↔cuidador e catálogo de medicamentos consumido pelo app Flutter.

## Rodar

```powershell
$env:JAVA_HOME = "C:\caminho\para\jdk17+"   # o java do PATH pode ser 1.8
cd backend
.\mvnw.cmd spring-boot:run
```

Sobe em `http://0.0.0.0:8080`. Console do H2: `http://localhost:8080/h2-console`.

## Testes

```powershell
.\mvnw.cmd test
```

25 testes: contrato HTTP (`ApiContratoTest`), regras de estoque
(`CalculoEstoqueTest`), login (`AuthServiceTest`) e RN01 (`VinculoServiceTest`).
Usam H2 em memória e **não** tocam `backend/data/`.

## Configuração

| Variável | Padrão | Efeito |
| --- | --- | --- |
| `GOOGLE_CLIENT_ID` | vazio | Vazio = modo dev (aceita qualquer token). Defina para validar de verdade. |
| `PORT` | `8080` | Porta HTTP |
| `CUIDAMED_DEV` | `false` | Reservado |

`cuidamed.vinculo.max-cuidadores-por-paciente` (padrão 2) controla a RN01.

## Endpoints

| Método | Rota | Quem |
| --- | --- | --- |
| POST | `/api/auth/google-token` | público |
| POST | `/api/auth/vincular` | cuidador (a si mesmo) |
| GET | `/api/auth/paciente/{id}/cuidadores` | — |
| GET | `/api/auth/cuidador/{id}/pacientes` | — |
| DELETE | `/api/auth/vincular/{id}` | participante do vínculo |
| GET | `/api/medicamentos/paciente/{id}` | paciente ou cuidador vinculado |
| POST/PUT/DELETE | `/api/medicamentos/paciente/{id}...` | só o paciente |
| POST | `/api/medicamentos/paciente/{id}/{medId}/repor` | só o paciente |
| POST | `/api/medicamentos/paciente/{id}/{medId}/dose` | só o paciente |

Todas as rotas de medicamento exigem o header `X-Usuario-Id`.
Erros sempre no formato `{ "erro": "mensagem" }`.

## Limitação conhecida

`X-Usuario-Id` **não é assinado**: um cliente pode enviar outro id. As regras de
autorização estão corretas, mas a identidade não é garantida. Para produção,
troque o header por JWT assinado (Spring Security). Em rede local de MVP é
aceitável.
