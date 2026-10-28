package fitgym.app.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.JoinColumn;

@Entity
public class Rutina_Ejercicio {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    Integer id;
    @ManyToOne
    @JoinColumn(name="rutina_id")
    private Rutina rutina_id;
    @ManyToOne
    @JoinColumn(name="ejercicio_id")
    private Ejercicios ejercicio_id;
    private Integer Series;
    private Integer Repeticiones;


    public Integer getId() {
        return this.id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public Rutina getRutina_id() {
        return this.rutina_id;
    }

    public void setRutina_id(Rutina rutina_id) {
        this.rutina_id = rutina_id;
    }

    public Ejercicios getEjercicio_id() {
        return this.ejercicio_id;
    }

    public void setEjercicio_id(Ejercicios ejercicio_id) {
        this.ejercicio_id = ejercicio_id;
    }

    public Integer getSeries() {
        return this.Series;
    }

    public void setSeries(Integer Series) {
        this.Series = Series;
    }

    public Integer getRepeticiones() {
        return this.Repeticiones;
    }

    public void setRepeticiones(Integer Repeticiones) {
        this.Repeticiones = Repeticiones;
    }

}
