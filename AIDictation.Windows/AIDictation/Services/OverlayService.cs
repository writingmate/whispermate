using System;
using System.Windows;
using AIDictation.Models;
using AIDictation.Views;

namespace AIDictation.Services;

/// <summary>
/// Manages the overlay window lifecycle, positioning, and visibility settings.
/// </summary>
public class OverlayService
{
    // MARK: - Singleton
    
    private static readonly Lazy<OverlayService> _instance = new(() => new OverlayService());
    public static OverlayService Shared => _instance.Value;
    
    // MARK: - Private Properties
    
    private OverlayWindow? _overlayWindow;
    private OverlayPosition _position = OverlayPosition.Bottom;
    private bool _hideWhenIdle = false;
    private bool _isEnabled = true;
    
    // MARK: - Initialization
    
    private OverlayService() { }
    
    // MARK: - Public API
    
    /// <summary>
    /// Initializes and shows the overlay window
    /// </summary>
    public void Initialize()
    {
        if (_overlayWindow != null) return;
        
        Application.Current.Dispatcher.Invoke(() =>
        {
            _overlayWindow = new OverlayWindow();
            _overlayWindow.SetPosition(_position);
            _overlayWindow.SetHideWhenIdle(_hideWhenIdle);
            
            if (_isEnabled)
            {
                _overlayWindow.Show();
            }
        });
    }
    
    /// <summary>
    /// Updates the overlay position (Top or Bottom)
    /// </summary>
    public void SetPosition(OverlayPosition position)
    {
        _position = position;
        Application.Current?.Dispatcher.Invoke(() =>
        {
            _overlayWindow?.SetPosition(position);
        });
    }
    
    /// <summary>
    /// Sets whether to hide the overlay when idle
    /// </summary>
    public void SetHideWhenIdle(bool hide)
    {
        _hideWhenIdle = hide;
        Application.Current?.Dispatcher.Invoke(() =>
        {
            _overlayWindow?.SetHideWhenIdle(hide);
        });
    }
    
    /// <summary>
    /// Enables or disables the overlay
    /// </summary>
    public void SetEnabled(bool enabled)
    {
        _isEnabled = enabled;
        Application.Current?.Dispatcher.Invoke(() =>
        {
            if (_overlayWindow == null) return;
            
            if (enabled)
            {
                _overlayWindow.ShowOverlay();
            }
            else
            {
                _overlayWindow.HideOverlay();
            }
        });
    }
    
    /// <summary>
    /// Shows the overlay window
    /// </summary>
    public void Show()
    {
        if (!_isEnabled) return;
        
        Application.Current?.Dispatcher.Invoke(() =>
        {
            _overlayWindow?.ShowOverlay();
        });
    }
    
    /// <summary>
    /// Hides the overlay window
    /// </summary>
    public void Hide()
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            _overlayWindow?.HideOverlay();
        });
    }
    
    /// <summary>
    /// Closes and disposes the overlay window
    /// </summary>
    public void Shutdown()
    {
        Application.Current?.Dispatcher.Invoke(() =>
        {
            _overlayWindow?.Close();
            _overlayWindow = null;
        });
    }
    
    /// <summary>
    /// Applies settings from AppSettings
    /// </summary>
    public void ApplySettings(AppSettings settings)
    {
        SetPosition(settings.OverlayPosition);
        SetHideWhenIdle(settings.HideIdleOverlay);
    }
}
