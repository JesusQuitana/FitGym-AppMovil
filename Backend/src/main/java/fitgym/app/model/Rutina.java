package fitgym.app.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;

@Entity
public class Rutina {

    @Id
    @GeneratedValue(strategy=GenerationType.IDENTITY)
    Integer id;
    String dia_semana;
    @ManyToOne
    @JoinColumn(name="cliente_id")
    private Cliente cliente_id;


    public Integer getId() {
        return this.id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getDia_semana() {
        return this.dia_semana;
    }

    public void setDia_semana(String dia_semana) {
        this.dia_semana = dia_semana;
    }

    public Cliente getCliente_id() {
        return this.cliente_id;
    }

    public void setCliente_id(Cliente cliente_id) {
        this.cliente_id = cliente_id;
    }
}
