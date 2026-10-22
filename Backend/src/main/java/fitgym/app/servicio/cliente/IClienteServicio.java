package fitgym.app.servicio.cliente;

import java.util.List;

import fitgym.app.model.Cliente;

public interface IClienteServicio {
    public List<Cliente> listarClientes();
    public Cliente buscarClienteId(Integer id);
    public Cliente saveCliente(Cliente cliente);
    public void deleteId(Integer id);
}
