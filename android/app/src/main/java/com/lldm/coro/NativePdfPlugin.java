package com.lldm.coro;

import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageButton;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import com.github.barteksc.pdfviewer.PDFView;
import com.github.barteksc.pdfviewer.listener.OnPageChangeListener;
import com.github.barteksc.pdfviewer.listener.OnErrorListener;
import com.github.barteksc.pdfviewer.listener.OnLoadCompleteListener;
import com.github.barteksc.pdfviewer.listener.OnTapListener;
import android.view.MotionEvent;

import java.io.File;

@CapacitorPlugin(name = "NativePdf")
public class NativePdfPlugin extends Plugin {

    private FrameLayout pdfViewContainer;
    private PDFView pdfView;

    @PluginMethod
    public void openPdf(PluginCall call) {
        String path = call.getString("path");
        if (path == null) {
            call.reject("No path provided");
            return;
        }
        
        // Remove "file://" prefix if present
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        
        final String finalPath = path;
        Integer startPageObj = call.getInt("startPage");
        final int startPage = startPageObj != null ? startPageObj : 0;

        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ViewGroup rootView = (ViewGroup) getActivity().getWindow().getDecorView();

                // 1. Container
                pdfViewContainer = new FrameLayout(getContext());
                FrameLayout.LayoutParams containerParams = new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, 
                        ViewGroup.LayoutParams.MATCH_PARENT
                );
                // Dar margen superior para no tapar la barra superior (HTML)
                float density = getContext().getResources().getDisplayMetrics().density;
                containerParams.topMargin = (int)(76 * density);
                pdfViewContainer.setLayoutParams(containerParams);
                pdfViewContainer.setBackgroundColor(Color.parseColor("#1a1a2e"));

                // 2. Native PDF Viewer
                pdfView = new PDFView(getContext(), null);
                pdfView.setLayoutParams(new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, 
                        ViewGroup.LayoutParams.MATCH_PARENT
                ));

                // 3. Configure
                PDFView.Configurator configurator;
                if (finalPath.contains("android_asset/")) {
                    String assetPath = finalPath.substring(finalPath.indexOf("android_asset/") + 14);
                    configurator = pdfView.fromAsset(assetPath);
                } else {
                    configurator = pdfView.fromFile(new File(finalPath));
                }

                configurator
                        .defaultPage(startPage)
                        .enableSwipe(true)
                        .swipeHorizontal(true)
                        .enableDoubletap(true)
                        .enableAntialiasing(true) // Suavizado de líneas
                        .fitEachPage(true) // Ajusta óptimamente la resolución según la pantalla
                        .spacing(8)
                        .onTap(new OnTapListener() {
                            @Override
                            public boolean onTap(MotionEvent e) {
                                if (pdfView == null) return false;
                                int width = pdfView.getWidth();
                                float x = e.getX();
                                int currentPage = pdfView.getCurrentPage();
                                int pageCount = pdfView.getPageCount();
                                
                                if (x < width * 0.2f) {
                                    if (currentPage > 0) {
                                        pdfView.jumpTo(currentPage - 1, true); // true = animado
                                    }
                                    return true; // evento consumido
                                } else if (x > width * 0.8f) {
                                    if (currentPage < pageCount - 1) {
                                        pdfView.jumpTo(currentPage + 1, true);
                                    }
                                    return true; // evento consumido
                                }
                                return false;
                            }
                        })
                        .onPageChange(new OnPageChangeListener() {
                            @Override
                            public void onPageChanged(int page, int pageCount) {
                                JSObject data = new JSObject();
                                data.put("page", page);
                                notifyListeners("pageChanged", data);
                            }
                        })
                        .onError(new OnErrorListener() {
                            @Override
                            public void onError(Throwable t) {
                                getActivity().runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
                                        if (pdfViewContainer != null && rootView != null) {
                                            rootView.removeView(pdfViewContainer);
                                        }
                                    }
                                });
                                call.reject("Error al cargar PDF: " + t.getMessage());
                            }
                        })
                        .onLoad(new OnLoadCompleteListener() {
                            @Override
                            public void loadComplete(int nbPages) {
                                getActivity().runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
                                        if (pdfViewContainer != null) {
                                            pdfViewContainer.setVisibility(View.VISIBLE);
                                        }
                                    }
                                });
                                call.resolve();
                            }
                        })
                        .load();

                // Añadirlo invisible para que Android pueda medirlo, de lo contrario nunca cargará.
                pdfViewContainer.setVisibility(View.INVISIBLE);
                pdfViewContainer.addView(pdfView);
                rootView.addView(pdfViewContainer);
            }
        });
    }

    @PluginMethod
    public void closePdf(PluginCall call) {
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                closePdfInternal();
                call.resolve();
            }
        });
    }

    @PluginMethod
    public void setDrawingMode(PluginCall call) {
        Boolean activeObj = call.getBoolean("active");
        final boolean active = activeObj != null ? activeObj : false;
        
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (pdfView != null) {
                    // Disable gestures on the PDF view if drawing is active
                    pdfView.setSwipeEnabled(!active);
                }
            }
        });
        call.resolve();
    }
    
    @PluginMethod
    public void jumpToPage(PluginCall call) {
        Integer pageObj = call.getInt("page");
        final int page = pageObj != null ? pageObj : 0;
        
        getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (pdfView != null) {
                    pdfView.jumpTo(page, true);
                }
            }
        });
        call.resolve();
    }

    private void closePdfInternal() {
        if (pdfViewContainer != null) {
            ViewGroup rootView = (ViewGroup) getActivity().getWindow().getDecorView();
            rootView.removeView(pdfViewContainer);
            pdfViewContainer = null;
            pdfView = null;
            notifyListeners("pdfClosed", new JSObject());
        }
    }
}
