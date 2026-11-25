package br.com.cuidamed.controller;

import br.com.cuidamed.dto.GoogleTokenRequest;
import br.com.cuidamed.dto.UsuarioResponse;
import br.com.cuidamed.dto.VinculoFamiliarResponse;
import br.com.cuidamed.dto.VincularRequest;
import br.com.cuidamed.service.AuthService;
import br.com.cuidamed.service.VinculoService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoints consumidos por {@code AuthVinculoService} no app.
 *
 * <p>
 * Rotas e verbos aqui sao contrato: mudar qualquer um quebra o cliente.
 * </p>
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final VinculoService vinculoService;

    public AuthController(AuthService authService, VinculoService vinculoService) {
        this.authService = authService;
        this.vinculoService = vinculoService;
    }

    /** POST /api/auth/google-token — login com Google. */
    @PostMapping("/google-token")
    public ResponseEntity<UsuarioResponse> login(@Valid @RequestBody GoogleTokenRequest request) {
        return ResponseEntity.ok(authService.autenticar(request.idToken(), request.tipoPerfil()));
    }

    /**
     * POST /api/auth/vincular — cuidador vincula um paciente pelo codigo
     * (RN01/RN03).
     */
    @PostMapping("/vincular")
    public ResponseEntity<Void> vincular(
            @Valid @RequestBody VincularRequest request,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioLogadoId) {
        vinculoService.vincular(request.cuidadorId(), usuarioLogadoId, request.codigoVinculo());
        return ResponseEntity.ok().build();
    }

    /** GET /api/auth/paciente/{pacienteId}/cuidadores. */
    @GetMapping("/paciente/{pacienteId}/cuidadores")
    public List<VinculoFamiliarResponse> listarCuidadores(@PathVariable Long pacienteId) {
        return vinculoService.listarCuidadoresDoPaciente(pacienteId);
    }

    /** GET /api/auth/cuidador/{cuidadorId}/pacientes. */
    @GetMapping("/cuidador/{cuidadorId}/pacientes")
    public List<VinculoFamiliarResponse> listarPacientes(@PathVariable Long cuidadorId) {
        return vinculoService.listarPacientesDoCuidador(cuidadorId);
    }

    /** DELETE /api/auth/vincular/{vinculoId} — encerra o vinculo e libera vaga. */
    @DeleteMapping("/vincular/{vinculoId}")
    public ResponseEntity<Void> desvincular(
            @PathVariable Long vinculoId,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioLogadoId) {
        vinculoService.desvincular(vinculoId, usuarioLogadoId);
        return ResponseEntity.ok().build();
    }
}
