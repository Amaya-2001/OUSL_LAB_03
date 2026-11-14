package com.ousl.studentapi;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/** Data sent by the client. Kept separate from the entity so users cannot set fields like id. */
public record StudentRequest(
        @NotBlank String name,
        @NotBlank @Email String email,
        @NotBlank String course) {
}
