package br.com.cuidamed.service;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import br.com.cuidamed.domain.TipoPerfil;
import br.com.cuidamed.domain.Usuario;
import br.com.cuidamed.repository.UsuarioRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
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
 * Isolamento do catalogo entre pacientes.
 *
 * <p>
 * O app gera ids por timestamp quando o item e criado offline. Dois
 * pacientes usando o app por mais de 1 ms em paralelo podem gerar o MESMO id —
 * se a chave primaria for apenas o id, o segundo paciente colide com o
 * primeiro.
 * </p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class IsolamentoCatalogoTest {

        @Autowired
        private MockMvc mockMvc;

        @Autowired
        private ObjectMapper objectMapper;

        @Autowired
        private UsuarioRepository usuarioRepository;

        @Autowired
        private CodigoVinculoGenerator codigoGenerator;

        private String corpo(String id, String nome) throws Exception {
                return objectMapper.writeValueAsString(Map.of(
                                "id", id,
                                "nome", nome,
                                "dosagem", "50mg",
                                "horario", "08:00",
                                "quantidadePorDose", 1,
                                "quantidadeTotal", 30));
        }

        @Test
        @DisplayName("mesmo id em pacientes diferentes NAO colide")
        void mesmoIdPacientesDiferentes() throws Exception {
                Usuario ana = usuarioRepository.save(new Usuario(
                                "Ana", "ana@isolamento.com", null, TipoPerfil.PACIENTE, codigoGenerator.gerar()));
                Usuario bruno = usuarioRepository.save(new Usuario(
                                "Bruno", "bruno@isolamento.com", null, TipoPerfil.PACIENTE, codigoGenerator.gerar()));

                // Id idêntico nos dois catálogos (cenário real: timestamp coincidente).
                mockMvc.perform(post("/api/medicamentos/paciente/{id}", ana.getId())
                                .header("X-Usuario-Id", ana.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(corpo("1780000000000", "Losartana da Ana")))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .status().isCreated());

                mockMvc.perform(post("/api/medicamentos/paciente/{id}", bruno.getId())
                                .header("X-Usuario-Id", bruno.getId())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(corpo("1780000000000", "Metformina do Bruno")))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .status().isCreated());

                // Cada um ve apenas o seu.
                mockMvc.perform(get("/api/medicamentos/paciente/{id}", ana.getId())
                                .header("X-Usuario-Id", ana.getId()))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .jsonPath("$.length()").value(1))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .jsonPath("$[0].nome").value("Losartana da Ana"));

                mockMvc.perform(get("/api/medicamentos/paciente/{id}", bruno.getId())
                                .header("X-Usuario-Id", bruno.getId()))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .jsonPath("$.length()").value(1))
                                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers
                                                .jsonPath("$[0].nome").value("Metformina do Bruno"));
        }
}
