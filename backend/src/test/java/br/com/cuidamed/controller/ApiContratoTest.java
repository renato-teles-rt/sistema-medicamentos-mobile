package br.com.cuidamed.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.cuidamed.domain.TipoPerfil;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.repository.MedicamentoRepository;
import br.com.cuidamed.repository.UsuarioRepository;
import br.com.cuidamed.repository.VinculoFamiliarRepository;
import br.com.cuidamed.service.CodigoVinculoGenerator;
import br.com.cuidamed.service.VinculoService;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

/**
 * Testes de contrato HTTP: verificam rotas, status e formato JSON que o app
 * consome (incluindo o campo {@code erro}).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ApiContratoTest {

        @Autowired
        private MockMvc mockMvc;

        @Autowired
        private ObjectMapper objectMapper;

        @Autowired
        private UsuarioRepository usuarioRepository;

        @Autowired
        private VinculoFamiliarRepository vinculoRepository;

        @Autowired
        private MedicamentoRepository medicamentoRepository;

        @Autowired
        private VinculoService vinculoService;

        @Autowired
        private CodigoVinculoGenerator codigoGenerator;

        private Usuario paciente;
        private Usuario cuidador;

        @BeforeEach
        void preparar() {
                paciente = usuarioRepository.save(
                                new Usuario("Dona Maria", "maria@api.com", null, TipoPerfil.PACIENTE,
                                                codigoGenerator.gerar()));
                cuidador = usuarioRepository.save(
                                new Usuario("Joao", "joao@api.com", null, TipoPerfil.CUIDADOR,
                                                codigoGenerator.gerar()));
        }

        private String json(Object corpo) throws Exception {
                return objectMapper.writeValueAsString(corpo);
        }

        @Test
        @DisplayName("GET medicamentos sem sessao retorna 401 com campo erro")
        void semSessaoRetornaErro() throws Exception {
                mockMvc.perform(get("/api/medicamentos/paciente/{id}", paciente.getId()))
                                .andExpect(status().isUnauthorized())
                                .andExpect(jsonPath("$.erro").isNotEmpty());
        }

        @Test
        @DisplayName("POST cria medicamento e GET lista ordenado pelo nome")
        void criaEListaMedicamentos() throws Exception {
                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "id", "b",
                                                "nome", "Losartana",
                                                "dosagem", "50mg",
                                                "horario", "08:00",
                                                "quantidadePorDose", 1,
                                                "quantidadeTotal", 30))))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.nome").value("Losartana"))
                                .andExpect(jsonPath("$.diasRestantes").value(30))
                                .andExpect(jsonPath("$.statusEstoque").value("NORMAL"));

                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "id", "a",
                                                "nome", "AAS",
                                                "dosagem", "100mg",
                                                "horario", "12:00",
                                                "quantidadePorDose", 1,
                                                "quantidadeTotal", 2))))
                                .andExpect(status().isCreated())
                                .andExpect(jsonPath("$.statusEstoque").value("BAIXO"));

                mockMvc.perform(get("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId()))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$[0].nome").value("AAS"))
                                .andExpect(jsonPath("$[1].nome").value("Losartana"));
        }

        @Test
        @DisplayName("duplicidade de nome + dosagem e recusada (RN05)")
        void duplicidadeRecusada() throws Exception {
                String corpo = json(Map.of(
                                "nome", "Losartana", "dosagem", "50mg", "horario", "08:00",
                                "quantidadePorDose", 1, "quantidadeTotal", 30));

                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON).content(corpo))
                                .andExpect(status().isCreated());

                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON).content(corpo))
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.erro").value("Este medicamento ja esta no catalogo."));
        }

        @Test
        @DisplayName("validacao recusa dose zero e horario fora do formato")
        void validacaoDeCampos() throws Exception {
                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "nome", "X", "dosagem", "1mg", "horario", "25:99",
                                                "quantidadePorDose", 0, "quantidadeTotal", 5))))
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.erro").isNotEmpty());
        }

        @Test
        @DisplayName("repor soma e dose trava em zero")
        void reporEDose() throws Exception {
                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "id", "a", "nome", "AAS", "dosagem", "100mg", "horario", "12:00",
                                                "quantidadePorDose", 3, "quantidadeTotal", 1))));

                mockMvc.perform(post("/api/medicamentos/paciente/{p}/{m}/dose", paciente.getId(), "a")
                                .header("X-Usuario-Id", paciente.getId()))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.quantidadeTotal").value(0))
                                .andExpect(jsonPath("$.statusEstoque").value("ESGOTADO"));

                mockMvc.perform(post("/api/medicamentos/paciente/{p}/{m}/repor", paciente.getId(), "a")
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of("quantidade", 30))))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$.quantidadeTotal").value(30));
        }

        @Test
        @DisplayName("cuidador vinculado le o catalogo, mas nao escreve")
        void cuidadorSomenteLeitura() throws Exception {
                vinculoService.vincular(cuidador.getId(), cuidador.getId(), paciente.getCodigoVinculo());

                mockMvc.perform(get("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", cuidador.getId()))
                                .andExpect(status().isOk());

                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", cuidador.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "nome", "Y", "dosagem", "1mg", "horario", "08:00",
                                                "quantidadePorDose", 1, "quantidadeTotal", 1))))
                                .andExpect(status().isUnauthorized())
                                .andExpect(jsonPath("$.erro").isNotEmpty());
        }

        @Test
        @DisplayName("cuidador sem vinculo nao acessa o catalogo")
        void cuidadorSemVinculoBloqueado() throws Exception {
                mockMvc.perform(get("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", cuidador.getId()))
                                .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("rotas de vinculo respondem no formato do app")
        void rotasDeVinculo() throws Exception {
                mockMvc.perform(post("/api/auth/vincular")
                                .header("X-Usuario-Id", cuidador.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of("cuidadorId", cuidador.getId(), "codigoVinculo",
                                                paciente.getCodigoVinculo()))))
                                .andExpect(status().isOk());

                mockMvc.perform(get("/api/auth/cuidador/{id}/pacientes", cuidador.getId()))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$[0].paciente.email").value("maria@api.com"))
                                .andExpect(jsonPath("$[0].cuidador.email").value("joao@api.com"))
                                .andExpect(jsonPath("$[0].ativo").value(true));

                Long vinculoId = vinculoRepository.findByCuidadorIdAndAtivoTrueOrderByCriadoEmAsc(cuidador.getId())
                                .get(0).getId();

                mockMvc.perform(delete("/api/auth/vincular/{id}", vinculoId)
                                .header("X-Usuario-Id", paciente.getId()))
                                .andExpect(status().isOk());

                assertThat(vinculoRepository.countByPacienteIdAndAtivoTrue(paciente.getId())).isZero();
        }

        @Test
        @DisplayName("remover medicamento responde 200 e some da listagem")
        void removerMedicamento() throws Exception {
                mockMvc.perform(post("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(json(Map.of(
                                                "id", "z", "nome", "Zolpidem", "dosagem", "10mg", "horario", "22:00",
                                                "quantidadePorDose", 1, "quantidadeTotal", 10))));

                mockMvc.perform(delete("/api/medicamentos/paciente/{p}/{m}", paciente.getId(), "z")
                                .header("X-Usuario-Id", paciente.getId()))
                                .andExpect(status().isOk());

                mockMvc.perform(get("/api/medicamentos/paciente/{id}", paciente.getId())
                                .header("X-Usuario-Id", paciente.getId()))
                                .andExpect(status().isOk())
                                .andExpect(jsonPath("$").isEmpty());

                assertThat(medicamentoRepository.count()).isZero();
        }
}
