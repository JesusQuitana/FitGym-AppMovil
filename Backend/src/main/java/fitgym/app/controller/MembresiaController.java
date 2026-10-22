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
import fitgym.app.model.Membresia;
import fitgym.app.servicio.membresia.MembresiaServicio;

@RestController
@RequestMapping("appgym-movil")
@CrossOrigin(value="http://localhost:4200")
public class MembresiaController {
    private static final Logger logger = LoggerFactory.getLogger(MembresiaController.class);

    @Autowired
    private MembresiaServicio membresiaServicio;

    @GetMapping("/membresias")
    public List<Membresia> obtenerMembresias() {
        List<Membresia> Membresias = this.membresiaServicio.listarMembresia();
        logger.info("Membresias");
        Membresias.forEach(Membresia -> logger.info(Membresia.toString()));
        return Membresias;
    }

    @PostMapping("/Membresia/agregar")
    public Membresia add(@RequestBody Membresia Membresia) {
        logger.info("Membresia a Agregar: " + Membresia);
        return this.membresiaServicio.saveMembresia(Membresia);
    }

    @GetMapping("/membresia/buscar/{id}")
    public ResponseEntity<Membresia> getMembresiaById(@PathVariable int id) {
        Membresia Membresia = this.membresiaServicio.buscarMembresiaId(id);
        if(Membresia!=null) {
            return ResponseEntity.ok(Membresia);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Membresia");
        }
    }

    @PutMapping("/membresia/editar/{id}")
    public ResponseEntity<Membresia> updateMembresia(
        @PathVariable int id,
        @RequestBody Membresia membresia
    ) {
        Membresia MembresiaActualizar = this.membresiaServicio.buscarMembresiaId(id);
        MembresiaActualizar.setMembresia(membresia.getMembresia());
        //Guardar
        this.membresiaServicio.saveMembresia(MembresiaActualizar);
        return ResponseEntity.ok(MembresiaActualizar);
    }

    @DeleteMapping("/membresia/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Membresia membresia = this.membresiaServicio.buscarMembresiaId(id);
        logger.info(membresia.toString());
        if(membresia!=null) {
            this.membresiaServicio.deleteId(membresia.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
}
