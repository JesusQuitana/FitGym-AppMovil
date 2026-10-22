package fitgym.app.servicio.membresia;

import java.util.List;
import fitgym.app.model.Membresia;

public interface IMembresiaServicio {
    public List<Membresia> listarMembresia();
    public Membresia buscarMembresiaId(Integer id);
    public Membresia saveMembresia(Membresia membresia);
    public void deleteId(Integer id);
}
