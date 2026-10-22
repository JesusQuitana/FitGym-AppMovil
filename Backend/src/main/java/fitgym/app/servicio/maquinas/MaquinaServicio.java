package fitgym.app.servicio.maquinas;

import java.util.List;

import org.springframework.stereotype.Service;
import fitgym.app.model.Maquinas;
import fitgym.app.repositorio.MaquinasRepositorio;

@Service 
public class MaquinaServicio implements IMaquinasServicio{

    private final MaquinasRepositorio maquinasRepositorio;

    MaquinaServicio(MaquinasRepositorio maquinasRepositorio) {
        this.maquinasRepositorio = maquinasRepositorio;
    }

    @Override
    public List<Maquinas> listarMaquinas() {
        return this.maquinasRepositorio.findAll();
    }

    @Override
    public Maquinas buscarMaquinaId(Integer id) {
        Maquinas maquinas = this.maquinasRepositorio.findById(id).orElse(null);
        return maquinas;
    }

    @Override
    public Maquinas saveMaquina(Maquinas maquina) {
        return this.maquinasRepositorio.save(maquina);
    }

    @Override
    public void deleteId(Integer id) {
        this.maquinasRepositorio.deleteById(id);
    }

    
}
