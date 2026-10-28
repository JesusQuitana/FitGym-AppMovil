package fitgym.app.controller.ejercicioContro;

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
import fitgym.app.servicio.ejercicio.EjercicioServicio;
import fitgym.app.excepcion.RecursoNoEncontradoExcepcion;
import fitgym.app.model.Ejercicios;

@RestController
@RequestMapping("appgym-movil")
@CrossOrigin(value="http://localhost:3000")
public class EjercicioController {
    private static final Logger logger = LoggerFactory.getLogger(EjercicioController.class);

    @Autowired
    private EjercicioServicio ejercicioServicio;

    @GetMapping("/ejercicioss")
    public List<Ejercicios> obtenerEjercicioss() {
        List<Ejercicios> ejercicios = this.ejercicioServicio.listarEjercicios();
        logger.info("Ejercicioss");
        ejercicios.forEach(ejercicio -> logger.info(ejercicio.toString()));
        return ejercicios;
    }

    @PostMapping("/ejercicios/agregar")
    public Ejercicios add(@RequestBody Ejercicios ejercicios) {
        logger.info("Ejercicios a Agregar: " + ejercicios);
        return this.ejercicioServicio.saveEjercicios(ejercicios);
    }

    @GetMapping("/ejercicios/buscar/{id}")
    public ResponseEntity<Ejercicios> getEjerciciosById(@PathVariable int id) {
        Ejercicios ejercicios = this.ejercicioServicio.buscarEjerciciosId(id);
        if(ejercicios!=null) {
            return ResponseEntity.ok(ejercicios);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Ejercicios");
        }
    }

    @PutMapping("/ejercicios/editar/{id}")
    public ResponseEntity<Ejercicios> updateEjercicios(
        @PathVariable int id,
        @RequestBody Ejercicios ejercicios
    ) {
        Ejercicios EjerciciosActualizar = this.ejercicioServicio.buscarEjerciciosId(id);
        EjerciciosActualizar.setNombre(ejercicios.getNombre());
        EjerciciosActualizar.setDescripcion(ejercicios.getDescripcion());
        //Guardar
        this.ejercicioServicio.saveEjercicios(EjerciciosActualizar);
        return ResponseEntity.ok(EjerciciosActualizar);
    }

    @DeleteMapping("/ejercicios/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Ejercicios ejercicios = this.ejercicioServicio.buscarEjerciciosId(id);
        logger.info(ejercicios.toString());
        if(ejercicios!=null) {
            this.ejercicioServicio.deleteId(ejercicios.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
