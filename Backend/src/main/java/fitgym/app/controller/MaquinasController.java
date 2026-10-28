package fitgym.app.controller;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import fitgym.app.excepcion.RecursoNoEncontradoExcepcion;
import fitgym.app.model.Maquinas;
import fitgym.app.servicio.maquinas.MaquinaServicio;

@RestController
@RequestMapping("appgym-movil")
@CrossOrigin(value="http://localhost:3000")
public class MaquinasController {

    private static final Logger logger = LoggerFactory.getLogger(ClienteController.class);

    @Autowired
    private MaquinaServicio maquinaServicio;

    @GetMapping("/maquinas")
    public List<Maquinas> obtenerClientes() {
        List<Maquinas> Clientes = this.maquinaServicio.listarMaquinas();
        logger.info("Maquinas");
        Clientes.forEach(Cliente -> logger.info(Cliente.toString()));
        return Clientes;
    }

    @PostMapping("/maquina/agregar")
    public Maquinas add(@RequestBody Maquinas maquina) {
        logger.info("Cliente a Agregar: " + maquina);
        return this.maquinaServicio.saveMaquina(maquina);
    }

    @GetMapping("/maquina/buscar/{id}")
    public ResponseEntity<Maquinas> getClienteById(@PathVariable int id) {
        Maquinas maquina = this.maquinaServicio.buscarMaquinaId(id);
        if(maquina!=null) {
            return ResponseEntity.ok(maquina);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Cliente");
        }
    }

    @PutMapping("/maquina/editar/{id}")
    public ResponseEntity<Maquinas> updateMaquina(
        @PathVariable int id,
        @RequestBody Maquinas maquina
    ) {
        Maquinas maquinaActualizar = this.maquinaServicio.buscarMaquinaId(id);
        maquinaActualizar.setNombre(maquina.getNombre());
        maquinaActualizar.setDescripcion(maquina.getDescripcion());
        maquinaActualizar.setDisponibilidad(maquina.getDisponibilidad());
        maquinaActualizar.setGrupoMuscleGroup(maquina.getGrupoMuscleGroup());
        //Guardar
        this.maquinaServicio.saveMaquina(maquinaActualizar);
        return ResponseEntity.ok(maquinaActualizar);
    }

    @DeleteMapping("/maquina/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Maquinas maquina = this.maquinaServicio.buscarMaquinaId(id);
        logger.info(maquina.toString());
        if(maquina!=null) {
            this.maquinaServicio.deleteId(maquina.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}