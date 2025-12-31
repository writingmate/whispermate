using System;
using CredentialManagement;

namespace AIDictation.Helpers;

/// <summary>
/// Helper class for storing and retrieving credentials from Windows Credential Manager
/// </summary>
public static class CredentialHelper
{
    // MARK: - Constants

    private const string CredentialTarget = "AIDictation_Supabase_Session";
    private const string AccessTokenKey = "AccessToken";
    private const string RefreshTokenKey = "RefreshToken";
    private const string ExpiresAtKey = "ExpiresAt";

    // MARK: - Public API

    /// <summary>
    /// Saves session tokens to Windows Credential Manager
    /// </summary>
    public static void SaveSession(string accessToken, string refreshToken, DateTimeOffset expiresAt)
    {
        SaveCredential($"{CredentialTarget}_{AccessTokenKey}", accessToken);
        SaveCredential($"{CredentialTarget}_{RefreshTokenKey}", refreshToken);
        SaveCredential($"{CredentialTarget}_{ExpiresAtKey}", expiresAt.ToUnixTimeSeconds().ToString());
    }

    /// <summary>
    /// Retrieves session tokens from Windows Credential Manager
    /// </summary>
    /// <returns>Tuple of (accessToken, refreshToken, expiresAt) or null if not found</returns>
    public static (string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt)? LoadSession()
    {
        var accessToken = LoadCredential($"{CredentialTarget}_{AccessTokenKey}");
        var refreshToken = LoadCredential($"{CredentialTarget}_{RefreshTokenKey}");
        var expiresAtStr = LoadCredential($"{CredentialTarget}_{ExpiresAtKey}");

        if (string.IsNullOrEmpty(accessToken) || 
            string.IsNullOrEmpty(refreshToken) || 
            string.IsNullOrEmpty(expiresAtStr))
        {
            return null;
        }

        if (!long.TryParse(expiresAtStr, out var expiresAtUnix))
        {
            return null;
        }

        var expiresAt = DateTimeOffset.FromUnixTimeSeconds(expiresAtUnix);
        return (accessToken, refreshToken, expiresAt);
    }

    /// <summary>
    /// Clears all stored session credentials
    /// </summary>
    public static void ClearSession()
    {
        DeleteCredential($"{CredentialTarget}_{AccessTokenKey}");
        DeleteCredential($"{CredentialTarget}_{RefreshTokenKey}");
        DeleteCredential($"{CredentialTarget}_{ExpiresAtKey}");
    }

    /// <summary>
    /// Checks if a session exists in storage
    /// </summary>
    public static bool HasStoredSession()
    {
        var accessToken = LoadCredential($"{CredentialTarget}_{AccessTokenKey}");
        return !string.IsNullOrEmpty(accessToken);
    }

    // MARK: - Private Methods

    private static void SaveCredential(string target, string secret)
    {
        using var credential = new Credential
        {
            Target = target,
            Username = "AIDictation",
            Password = secret,
            PersistanceType = PersistanceType.LocalComputer
        };
        credential.Save();
    }

    private static string? LoadCredential(string target)
    {
        using var credential = new Credential { Target = target };
        if (credential.Load())
        {
            return credential.Password;
        }
        return null;
    }

    private static void DeleteCredential(string target)
    {
        using var credential = new Credential { Target = target };
        credential.Delete();
    }
}
