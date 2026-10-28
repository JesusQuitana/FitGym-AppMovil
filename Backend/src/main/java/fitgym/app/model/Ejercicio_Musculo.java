package fitgym.app.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.JoinColumn;

@Entity
public class Ejercicio_Musculo {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    private Integer id;
    @ManyToOne
    @JoinColumn(name="ejercicio_id")
    private Ejercicios ejercicio_id;
    @ManyToOne
    @JoinColumn(name="musculo_id")
    private MuscleGroup musculo_id;
    @ManyToOne
    @JoinColumn(name="maquina_id")
    private Maquinas maquina_id;


    public Integer getId() {
        return this.id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Ejercicios getEjercicio_id() {
        return this.ejercicio_id;
    }

    public void setEjercicio_id(Ejercicios ejercicio_id) {
        this.ejercicio_id = ejercicio_id;
    }

    public MuscleGroup getMusculo_id() {
        return this.musculo_id;
    }

    public void setMusculo_id(MuscleGroup musculo_id) {
        this.musculo_id = musculo_id;
    }

    public Maquinas getMaquina_id() {
        return this.maquina_id;
    }

    public void setMaquina_id(Maquinas maquina_id) {
        this.maquina_id = maquina_id;
    }
}
