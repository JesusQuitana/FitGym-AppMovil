package fitgym.app.servicio.cliente;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import fitgym.app.model.Cliente;
import fitgym.app.repositorio.ClienteRepositorio;

@Service
public class ClienteServicio implements IClienteServicio{

    @Autowired
    private ClienteRepositorio clienteRepositorio;

    @Override
    public List<Cliente> listarClientes() {
        return this.clienteRepositorio.findAll();
    }

    @Override
    public Cliente buscarClienteId(Integer id) {
        Cliente Cliente = this.clienteRepositorio.findById(id).orElse(null);
        return Cliente;
    }

    @Override
    public Cliente saveCliente(Cliente Cliente) {
        return this.clienteRepositorio.save(Cliente);
    }

    @Override
    public void deleteId(Integer id) {
        this.clienteRepositorio.deleteById(id);
    }
    
}
