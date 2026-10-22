package fitgym.app.servicio.user;

import java.util.List;
import fitgym.app.model.users.User;

public interface IUserService {
    User findById(Integer id);

    public void updateUser(User user);

    public List<User> findAll();

    public void deleteUser(User user);

    public void saveUser(User user);
}
