#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/select.h>

// Command map matches your JS script values
int get_command_code(const char *cmd) {
    if (strcmp(cmd, "power") == 0) return 0;
    if (strcmp(cmd, "select") == 0) return 1;
    if (strcmp(cmd, "backup") == 0 || strcmp(cmd, "dismiss") == 0) return 2;
    if (strcmp(cmd, "up") == 0) return 16;
    if (strcmp(cmd, "down") == 0) return 17;
    if (strcmp(cmd, "left") == 0) return 18;
    if (strcmp(cmd, "right") == 0) return 19;
    if (strcmp(cmd, "home") == 0) return 11;
    if (strcmp(cmd, "i") == 0) return 14;
    // Add additional commands here matching your JS list if needed
    return -1;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <ip_address> <command>\n", argv[0]);
        return 1;
    }

    char *host = argv[1];
    char *command = argv[2];
    int port = 49160; 
    
    int code = get_command_code(command);
    if (code == -1) {
        fprintf(stderr, "Error: Unknown command '%s'\n", command);
        return 1;
    }

    // Prepare your dynamic command bytes logic
    unsigned char commandBytes[8] = {4, 1, 0, 0, 0, 0, (unsigned char)(224 + (code / 16)), (unsigned char)(code % 16)};

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        return 1;
    }

    struct sockaddr_in serv_addr;
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    if (inet_pton(AF_INET, host, &serv_addr.sin_addr) <= 0) {
        perror("Invalid address");
        return 1;
    }

    // Connect with a 1-second timeout
    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, (const char*)&tv, sizeof(tv));
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));

    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("Connection Timeout/Failed");
        return 1;
    }

    unsigned char buffer[1024];
    int len;
    int handshake_stage = 0;

    // Emulate the client.on('data') event loop
    while ((len = recv(sock, buffer, sizeof(buffer), 0)) > 0) {
        if (len < 24 && handshake_stage == 0) {
            // Replicates: client.write(data.slice(0, 12)) then l = 1
            send(sock, buffer, 12, 0);
            handshake_stage = 1;
        } else {
            // Replicates: client.write(commandBytes) -> commandBytes[1]=0 -> client.write(commandBytes)
            send(sock, commandBytes, 8, 0);
            commandBytes[1] = 0;
            send(sock, commandBytes, 8, 0);
            break; // Replicates: client.destroy()
        }
    }

    close(sock);
    printf("Success: Sent '%s' to Sky Box at %s\n", command, host);
    return 0;
}
