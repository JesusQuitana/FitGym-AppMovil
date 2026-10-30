package fitgym.app.servicio.musclegroup;

import java.util.List;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import fitgym.app.repositorio.MuscleGroupRepository;
import fitgym.app.model.MuscleGroup;

@Service 
public class MuscleGroupServicio implements IMuscleGroupServicio{

    @Autowired
    private MuscleGroupRepository muscleGroupRepository;

    @Override
    public List<MuscleGroup> listarMuscleGroup() {
        return this.muscleGroupRepository.findAll();
    }

    @Override
    public MuscleGroup buscarMuscleGroupId(Integer id) {
        MuscleGroup muscle = this.muscleGroupRepository.findById(id).orElse(null);
        return muscle;
    }

    @Override
    public MuscleGroup saveMuscleGroup(MuscleGroup muscleGroup) {
        return this.muscleGroupRepository.save(muscleGroup);
    }

    @Override
    public void deleteId(Integer id) {
        this.muscleGroupRepository.deleteById(id);
    }

    

}
