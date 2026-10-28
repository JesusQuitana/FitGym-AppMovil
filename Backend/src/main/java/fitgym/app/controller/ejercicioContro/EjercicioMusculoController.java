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

import fitgym.app.excepcion.RecursoNoEncontradoExcepcion;
import fitgym.app.model.Ejercicio_Musculo;
import fitgym.app.servicio.ejercicio.EjercicioMusculoServicio;

@RestController
@RequestMapping("/appgym-movil/ejercicios/musculos")
@CrossOrigin(value="http://localhost:4200")
public class EjercicioMusculoController {
    private static final Logger logger = LoggerFactory.getLogger(EjercicioController.class);

    @Autowired
    private EjercicioMusculoServicio ejeMSer;

    @GetMapping
    public List<Ejercicio_Musculo> obtenerEjercicio_Musculos() {
        List<Ejercicio_Musculo> ejeM = this.ejeMSer.listarEjercicio_Musculos();
        logger.info("Ejercicio_Musculos");
        ejeM.forEach(ejercicio -> logger.info(ejercicio.toString()));
        return ejeM;
    }

    @PostMapping("/agregar")
    public Ejercicio_Musculo add(@RequestBody Ejercicio_Musculo ejeM) {
        logger.info("Entidad a Agregar: " + ejeM);
        return this.ejeMSer.saveEjercicio_Musculo(ejeM);
    }

    @GetMapping("/buscar/{id}")
    public ResponseEntity<Ejercicio_Musculo> getEjercicio_MusculoById(@PathVariable int id) {
        Ejercicio_Musculo ejeM = this.ejeMSer.buscarEjercicio_MusculoId(id);
        if(ejeM!=null) {
            return ResponseEntity.ok(ejeM);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Ejercicio_Musculo");
        }
    }

    @PutMapping("/editar/{id}")
    public ResponseEntity<Ejercicio_Musculo> updateEjercicio_Musculo(
        @PathVariable int id,
        @RequestBody Ejercicio_Musculo ejeM
    ) {
        Ejercicio_Musculo Ejercicio_MusculoActualizar = this.ejeMSer.buscarEjercicio_MusculoId(id);
        Ejercicio_MusculoActualizar.setEjercicio_id(ejeM.getEjercicio_id());
        Ejercicio_MusculoActualizar.setMusculo_id(ejeM.getMusculo_id());Ejercicio_MusculoActualizar.setMaquina_id(ejeM.getMaquina_id());
        //Guardar
        this.ejeMSer.saveEjercicio_Musculo(Ejercicio_MusculoActualizar);
        return ResponseEntity.ok(Ejercicio_MusculoActualizar);
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Ejercicio_Musculo ejeM = this.ejeMSer.buscarEjercicio_MusculoId(id);
        logger.info(ejeM.toString());
        if(ejeM!=null) {
            this.ejeMSer.deleteId(ejeM.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
