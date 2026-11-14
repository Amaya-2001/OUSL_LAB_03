package com.ousl.studentapi;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class StudentControllerTest {

    private static final String VALID = """
            {"name":"Nimal Perera","email":"nimal@example.com","course":"EEI6369"}
            """;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private StudentRepository repository;

    @BeforeEach
    void cleanDatabase() {
        repository.deleteAll();
    }

    private Long saveOne() {
        return repository.save(new Student("Kamal", "kamal@example.com", "EEI6369")).getId();
    }

    @Test
    void createStudentReturns201() throws Exception {
        mockMvc.perform(post("/api/students").contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.name").value("Nimal Perera"));
    }

    @Test
    void invalidStudentReturns400() throws Exception {
        mockMvc.perform(post("/api/students").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"email\":\"bad\",\"course\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getAllAndGetById() throws Exception {
        Long id = saveOne();
        mockMvc.perform(get("/api/students")).andExpect(status().isOk())
                .andExpect(jsonPath("$[0].email").value("kamal@example.com"));
        mockMvc.perform(get("/api/students/" + id)).andExpect(status().isOk())
                .andExpect(jsonPath("$.course").value("EEI6369"));
    }

    @Test
    void unknownStudentReturns404() throws Exception {
        mockMvc.perform(get("/api/students/9999")).andExpect(status().isNotFound());
    }

    @Test
    void updateStudent() throws Exception {
        Long id = saveOne();
        mockMvc.perform(put("/api/students/" + id).contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Nimal Perera"));
    }

    @Test
    void deleteStudent() throws Exception {
        Long id = saveOne();
        mockMvc.perform(delete("/api/students/" + id)).andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/students/" + id)).andExpect(status().isNotFound());
    }
}
