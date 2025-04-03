#include <stdio.h>
#include <string.h>
#include <windows.h>
#include <openssl/evp.h>
#include <openssl/pem.h>

int main()
{
    SetConsoleOutputCP(CP_UTF8);
    printf("RSA 키 생성\n");

    // 키생성
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
    if (!ctx)
    {
        printf("EVP_PKEY_CTX 생성 실패\n");
        return 1;
    }

    if (EVP_PKEY_keygen_init(ctx) <= 0)
    {
        printf("EVP_PKEY_keygen_init 실패\n");
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }

    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048) <= 0)
    {
        printf("키 길이 설정 실패\n");
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }

    EVP_PKEY* pkey = NULL;
    if (EVP_PKEY_keygen(ctx, &pkey) <= 0)
    {
        printf("EVP_PKEY 키 생성 실패\n");
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }

    // 공개키 저장
    FILE* fp_pub = fopen("rsa_public.pem", "wb");
    if (!fp_pub)
    {
        printf("공개키 파일 열기 실패\n");
        EVP_PKEY_free(pkey);
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }

    if (PEM_write_PUBKEY(fp_pub, pkey) == 0)
    {
        printf("공개키 저장 실패\n");
        fclose(fp_pub);
        EVP_PKEY_free(pkey);
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }
    fclose(fp_pub);

    // 개인키 저장
    FILE* fp_priv = fopen("rsa_private.pem", "wb");
    if (!fp_priv)
    {
        printf("개인키 파일 열기 실패\n");
        EVP_PKEY_free(pkey);
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }

    if (PEM_write_PrivateKey(fp_priv, pkey, NULL, NULL, 0, NULL, NULL) == 0)
    {
        printf("개인키 저장 실패\n");
        fclose(fp_priv);
        EVP_PKEY_free(pkey);
        EVP_PKEY_CTX_free(ctx);
        return 1;
    }
    fclose(fp_priv);

    //암호화
    //------------------------------------------------------------------
    //암호화할거
    const char* plaintext = "crl crl crl crl";

    //------------------------------------------------------------------
    unsigned char encrypted[256];
    size_t encrypted_len;

    EVP_PKEY_CTX* enc_ctx = EVP_PKEY_CTX_new(pkey, NULL);
    if (!enc_ctx)
    {
        printf("컨텍스트 생성 실패\n");
        return 1;
    }

    if (EVP_PKEY_encrypt_init(enc_ctx) <= 0)
    {
        printf("초기화 실패\n");
        return 1;
    }

    if (EVP_PKEY_encrypt(enc_ctx, NULL, &encrypted_len, (unsigned char*)plaintext, strlen(plaintext)) <= 0)
    {
        printf("길이 계산 실패\n");
        return 1;
    }

    if (EVP_PKEY_encrypt(enc_ctx, encrypted, &encrypted_len, (unsigned char*)plaintext, strlen(plaintext)) <= 0)
    {
        printf("실패\n");
        return 1;
    }

    EVP_PKEY_CTX_free(enc_ctx);
    printf(" %s\r\n", plaintext);


    printf("------------------------------------------------\r\n");


    printf("암호화:\r\n", encrypted_len);
    for (size_t i = 0; i < encrypted_len; i++)
    {
        printf("%02X ", encrypted[i]);
    }


    printf("\n");
    printf("------------------------------------------------\r\n");

    //복호화
    unsigned char decrypted[256];
    size_t decrypted_len;

    EVP_PKEY_CTX* dec_ctx = EVP_PKEY_CTX_new(pkey, NULL);
    if (!dec_ctx)
    {
        printf("복호화 컨텍스트 생성 실패\n");
        return 1;
    }

    if (EVP_PKEY_decrypt_init(dec_ctx) <= 0)
    {
        printf("복호화 초기화 실패\n");
        return 1;
    }

    if (EVP_PKEY_decrypt(dec_ctx, NULL, &decrypted_len, encrypted, encrypted_len) <= 0)
    {
        printf("복호화 길이 계산 실패\n");
        return 1;
    }

    if (EVP_PKEY_decrypt(dec_ctx, decrypted, &decrypted_len, encrypted, encrypted_len) <= 0)
    {
        printf("복호화 실패\n");
        return 1;
    }

    decrypted[decrypted_len] = '\0'; // 문자열 종료
    EVP_PKEY_CTX_free(dec_ctx);

    printf("복호화: %s\n", decrypted);

    // 메모리 해제
    EVP_PKEY_free(pkey);
    EVP_PKEY_CTX_free(ctx);

    printf("RSA 키 생성 완료\n");
    return 0;
}
