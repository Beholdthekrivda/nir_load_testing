#include <stdio.h>
#include <string.h>
#include <openssl/sha.h>

void print_sha1(const unsigned char *hash) {
    for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
        printf("%02x", hash[i]);
    }
    printf("\n");
}

int main() {
    const char *data = "Hello, world!";
    unsigned char hash[SHA_DIGEST_LENGTH]; // SHA_DIGEST_LENGTH равен 20 байтам

    // Вычисление SHA-1 за один вызов
    SHA1((const unsigned char *)data, strlen(data), hash);

    printf("Строка: %s\n", data);
    printf("SHA-1:  ");
    print_sha1(hash);

    return 0;
}

