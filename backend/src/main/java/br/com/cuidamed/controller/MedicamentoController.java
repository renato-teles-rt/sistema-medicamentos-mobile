package br.com.cuidamed.controller;

import br.com.cuidamed.dto.MedicamentoRequest;
import br.com.cuidamed.dto.MedicamentoResponse;
import br.com.cuidamed.dto.ReporEstoqueRequest;
import br.com.cuidamed.service.MedicamentoService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Catalogo de medicamentos. Todas as rotas exigem o header
 * {@code X-Usuario-Id}, enviado por {@code SessionService.headersAutenticados}.
 */
@RestController
@RequestMapping("/api/medicamentos")
public class MedicamentoController {

    private final MedicamentoService medicamentoService;

    public MedicamentoController(MedicamentoService medicamentoService) {
        this.medicamentoService = medicamentoService;
    }

    /** GET /api/medicamentos/paciente/{id} — usado por {@code sincronizar()}. */
    @GetMapping("/paciente/{pacienteId}")
    public List<MedicamentoResponse> listar(
            @PathVariable Long pacienteId,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        return medicamentoService.listar(pacienteId, usuarioId);
    }

    @GetMapping("/paciente/{pacienteId}/{medicamentoId}")
    public MedicamentoResponse buscar(
            @PathVariable Long pacienteId,
            @PathVariable String medicamentoId,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        return medicamentoService.buscar(pacienteId, medicamentoId, usuarioId);
    }

    @PostMapping("/paciente/{pacienteId}")
    public ResponseEntity<MedicamentoResponse> criar(
            @PathVariable Long pacienteId,
            @Valid @RequestBody MedicamentoRequest request,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        MedicamentoResponse criado = medicamentoService.criar(pacienteId, request, usuarioId);
        return ResponseEntity.status(HttpStatus.CREATED).body(criado);
    }

    @PutMapping("/paciente/{pacienteId}/{medicamentoId}")
    public MedicamentoResponse atualizar(
            @PathVariable Long pacienteId,
            @PathVariable String medicamentoId,
            @Valid @RequestBody MedicamentoRequest request,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        return medicamentoService.atualizar(pacienteId, medicamentoId, request, usuarioId);
    }

    /** Reposicao de estoque: soma unidades (nunca subtrai). */
    @PostMapping("/paciente/{pacienteId}/{medicamentoId}/repor")
    public MedicamentoResponse repor(
            @PathVariable Long pacienteId,
            @PathVariable String medicamentoId,
            @Valid @RequestBody ReporEstoqueRequest request,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        return medicamentoService.repor(pacienteId, medicamentoId, request.quantidade(), usuarioId);
    }

    /** Registro de dose tomada: trava em zero, nunca negativo. */
    @PostMapping("/paciente/{pacienteId}/{medicamentoId}/dose")
    public MedicamentoResponse registrarDose(
            @PathVariable Long pacienteId,
            @PathVariable String medicamentoId,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        return medicamentoService.registrarDose(pacienteId, medicamentoId, usuarioId);
    }

    @DeleteMapping("/paciente/{pacienteId}/{medicamentoId}")
    public ResponseEntity<Void> remover(
            @PathVariable Long pacienteId,
            @PathVariable String medicamentoId,
            @RequestHeader(value = "X-Usuario-Id", required = false) Long usuarioId) {
        medicamentoService.remover(pacienteId, medicamentoId, usuarioId);
        return ResponseEntity.ok().build();
    }
}
