package fitgym.app.controller;

import org.slf4j.Logger;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
import fitgym.app.model.MuscleGroup;
import fitgym.app.servicio.musclegroup.MuscleGroupServicio;

@RestController
@RequestMapping("appgym-movil")
@CrossOrigin(value="http//localhost:4200")
public class MuscleGroupController {

    private static final Logger logger = LoggerFactory.getLogger(MuscleGroupController.class);

    @Autowired
    private MuscleGroupServicio muscleGroupServicio;

    @GetMapping("/MuscleGroups")
    public List<MuscleGroup> obtenerMuscleGroups() {
        List<MuscleGroup> MuscleGroups = this.muscleGroupServicio.listarMuscleGroup();
        logger.info("MuscleGroups");
        MuscleGroups.forEach(MuscleGroup -> logger.info(MuscleGroup.toString()));
        return MuscleGroups;
    }

    @PostMapping("/MuscleGroup/agregar")
    public MuscleGroup add(@RequestBody MuscleGroup MuscleGroup) {
        logger.info("MuscleGroup a Agregar: " + MuscleGroup);
        return this.muscleGroupServicio.saveMuscleGroup(MuscleGroup);
    }

    @GetMapping("/MuscleGroup/buscar/{id}")
    public ResponseEntity<MuscleGroup> getMuscleGroupById(@PathVariable int id) {
        MuscleGroup MuscleGroup = this.muscleGroupServicio.buscarMuscleGroupId(id);
        if(MuscleGroup!=null) {
            return ResponseEntity.ok(MuscleGroup);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro MuscleGroup");
        }
    }

    @PutMapping("/MuscleGroup/editar/{id}")
    public ResponseEntity<MuscleGroup> updateMuscleGroup(
        @PathVariable int id,
        @RequestBody MuscleGroup muscleGroup
    ) {
        MuscleGroup MuscleGroupActualizar = this.muscleGroupServicio.buscarMuscleGroupId(id);
        MuscleGroupActualizar.setMusculo(muscleGroup.getMusculo());
        //Guardar
        this.muscleGroupServicio.saveMuscleGroup(MuscleGroupActualizar);
        return ResponseEntity.ok(MuscleGroupActualizar);
    }

    @DeleteMapping("/MuscleGroup/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        MuscleGroup MuscleGroup = this.muscleGroupServicio.buscarMuscleGroupId(id);
        logger.info(MuscleGroup.toString());
        if(MuscleGroup!=null) {
            this.muscleGroupServicio.deleteId(MuscleGroup.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
