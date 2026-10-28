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
import fitgym.app.model.Rutina_Ejercicio;
import fitgym.app.model.Rutina_Ejercicio;
import fitgym.app.servicio.rutina.RutinaEjercicioServicio;

@RestController
@RequestMapping("appmovil-gym/rutina/ejercicios")
@CrossOrigin(value="http://localhost:4200")
public class RutinaEjercicioController {
    private static final Logger logger = LoggerFactory.getLogger(RutinaEjercicioController.class);

    @Autowired
    private RutinaEjercicioServicio reServi;

    @GetMapping
    public List<Rutina_Ejercicio> obtenerRutina_Ejercicios() {
        List<Rutina_Ejercicio> ruEje = this.reServi.listarRutina_Ejercicios();
        logger.info("Rutina_Ejercicios");
        ruEje.forEach(ruEj -> logger.info(ruEj.toString()));
        return ruEje;
    }

    @PostMapping("/agregar")
    public Rutina_Ejercicio add(@RequestBody Rutina_Ejercicio ruEje) {
        logger.info("Entidad a Agregar: " + ruEje);
        return this.reServi.saveRutina_Ejercicio(ruEje);
    }

    @GetMapping("/buscar/{id}")
    public ResponseEntity<Rutina_Ejercicio> getRutina_EjercicioById(@PathVariable int id) {
        Rutina_Ejercicio ruEje = this.reServi.buscarRutina_EjercicioId(id);
        if(ruEje!=null) {
            return ResponseEntity.ok(ruEje);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Rutina_Ejercicio");
        }
    }

    @PutMapping("/editar/{id}")
    public ResponseEntity<Rutina_Ejercicio> updateRutina_Ejercicio(
        @PathVariable int id,
        @RequestBody Rutina_Ejercicio ruEje
    ) {
        Rutina_Ejercicio Rutina_EjercicioActualizar = this.reServi.buscarRutina_EjercicioId(id);
        Rutina_EjercicioActualizar.setRutina_id(ruEje.getRutina_id());
        Rutina_EjercicioActualizar.setEjercicio_id(ruEje.getEjercicio_id());
        Rutina_EjercicioActualizar.setRepeticiones(ruEje.getRepeticiones());
        Rutina_EjercicioActualizar.setSeries(ruEje.getSeries());
        //Guardar
        this.reServi.saveRutina_Ejercicio(Rutina_EjercicioActualizar);
        return ResponseEntity.ok(Rutina_EjercicioActualizar);
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Rutina_Ejercicio ruEje = this.reServi.buscarRutina_EjercicioId(id);
        logger.info(ruEje.toString());
        if(ruEje!=null) {
            this.reServi.deleteId(ruEje.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
