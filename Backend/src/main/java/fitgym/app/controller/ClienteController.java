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
import fitgym.app.model.Cliente;
import fitgym.app.servicio.cliente.ClienteServicio;


@RestController
@RequestMapping("appgym-movil") //http://localhost:3000/appgym-movil
@CrossOrigin(value="http://localhost:3000") //Puerto por default de Angular
public class ClienteController {
    private static final Logger logger = LoggerFactory.getLogger(ClienteController.class);

    @Autowired
    private ClienteServicio clienteServicio;

    @GetMapping("/clientes")
    public List<Cliente> obtenerClientes() {
        List<Cliente> Clientes = this.clienteServicio.listarClientes();
        logger.info("Clientes");
        Clientes.forEach(Cliente -> logger.info(Cliente.toString()));
        return Clientes;
    }

    @PostMapping("/cliente/agregar")
    public Cliente add(@RequestBody Cliente Cliente) {
        logger.info("Cliente a Agregar: " + Cliente);
        return this.clienteServicio.saveCliente(Cliente);
    }

    @GetMapping("/cliente/buscar/{id}")
    public ResponseEntity<Cliente> getClienteById(@PathVariable int id) {
        Cliente Cliente = this.clienteServicio.buscarClienteId(id);
        if(Cliente!=null) {
            return ResponseEntity.ok(Cliente);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro Cliente");
        }
    }

    @PutMapping("/cliente/editar/{id}")
    public ResponseEntity<Cliente> updateCliente(
        @PathVariable int id,
        @RequestBody Cliente cliente
    ) {
        Cliente clienteActualizar = this.clienteServicio.buscarClienteId(id);
        clienteActualizar.setNombre(cliente.getNombre());
        clienteActualizar.setApellido(cliente.getApellido());
        clienteActualizar.setCorreo(cliente.getCorreo());
        clienteActualizar.setTelefono(cliente.getTelefono());
        clienteActualizar.setMembresia_id(cliente.getMembresia_id());
        clienteActualizar.setFechaPago(cliente.getFechaPago());
        //Guardar
        this.clienteServicio.saveCliente(clienteActualizar);
        return ResponseEntity.ok(clienteActualizar);
    }

    @DeleteMapping("/cliente/delete/{id}")
    public ResponseEntity<Map<String, Boolean>> delete(@PathVariable int id) {
        Cliente cliente = this.clienteServicio.buscarClienteId(id);
        logger.info(cliente.toString());
        if(cliente!=null) {
            this.clienteServicio.deleteId(cliente.getId());
            Map<String, Boolean> response = new HashMap<>();
            response.put("Respuesta", true);
            return ResponseEntity.ok(response);
        }
        else {
            throw new RecursoNoEncontradoExcepcion("No se encontro el recurso");
        }
    }
    
}
