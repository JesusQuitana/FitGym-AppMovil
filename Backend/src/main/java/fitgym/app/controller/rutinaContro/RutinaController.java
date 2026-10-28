package fitgym.app.controller.rutinaContro;

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
import fitgym.app.model.Rutina;
import fitgym.app.servicio.rutina.RutinaServicio;

@RestController
@RequestMapping("appgym-movil")
@CrossOrigin(value="http://localhost:3000")
public class RutinaController {
    private static final Logger logger = LoggerFactory.getLogger(RutinaController.class);

    @Autowired
    private RutinaServicio rutinaServicio;

    @GetMapping("/rutinas")
    public List<Rutina> obtenerRutinas() {
        List<Rutina> rutinas = this.rutinaServicio.listarRutina();
        logger.info("Rutinas");
        rutinas.forEach(rutina -> logger.info(rutina.toString()));
        return rutinas;
    }

    @PostMapping("/rutina/agregar")
    public Rutina add(@RequestBody Rutina rutina) {
        logger.info("Rutina a Agregar: " + rutina);
        return this.rutinaServicio.saveRutina(rutina);
    }

    @GetMapping("/rutina/buscar/{id}")
    public ResponseEntity<Rutina> getRutinaById(@PathVariable int id) {
        Rutina rutina = this.rutinaServicio.buscarRutinaId(id);
        if(rutina!=null) {
            return ResponseEntity.ok(rutina);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Rutina");
        }
    }

    @PutMapping("/rutina/editar/{id}")
    public ResponseEntity<Rutina> updateRutina(
        @PathVariable int id,
        @RequestBody Rutina rutina
    ) {
        Rutina RutinaActualizar = this.rutinaServicio.buscarRutinaId(id);
        RutinaActualizar.setDia_semana(rutina.getDia_semana());
        RutinaActualizar.setCliente_id(rutina.getCliente_id());
        //Guardar
        this.rutinaServicio.saveRutina(RutinaActualizar);
        return ResponseEntity.ok(RutinaActualizar);
    }

    @DeleteMapping("/rutina/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Rutina rutina = this.rutinaServicio.buscarRutinaId(id);
        logger.info(rutina.toString());
        if(rutina!=null) {
            this.rutinaServicio.deleteId(rutina.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
