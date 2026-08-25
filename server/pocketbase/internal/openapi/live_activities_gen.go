package openapi

import (
	"context"
	"fmt"
	"net/http"
)

type EndLiveActivityRequestObject struct{ Id string }
type EndLiveActivityResponseObject interface {
	VisitEndLiveActivityResponse(http.ResponseWriter) error
}

// EndLiveActivity is the generated strict-handler bridge for the added route.
func (sh *strictHandler) EndLiveActivity(w http.ResponseWriter, r *http.Request, id string) {
	request := EndLiveActivityRequestObject{Id: id}
	handler := func(ctx context.Context, w http.ResponseWriter, r *http.Request, request interface{}) (interface{}, error) {
		return sh.ssi.EndLiveActivity(ctx, request.(EndLiveActivityRequestObject))
	}
	for _, middleware := range sh.middlewares {
		handler = middleware(handler, "EndLiveActivity")
	}
	response, err := handler(r.Context(), w, r, request)
	if err != nil {
		sh.options.ResponseErrorHandlerFunc(w, r, err)
		return
	}
	if valid, ok := response.(EndLiveActivityResponseObject); ok {
		if err := valid.VisitEndLiveActivityResponse(w); err != nil {
			sh.options.ResponseErrorHandlerFunc(w, r, err)
		}
		return
	}
	if response != nil {
		sh.options.ResponseErrorHandlerFunc(w, r, fmt.Errorf("unexpected response type: %T", response))
	}
}

// EndLiveActivity is the generated wrapper bridge for the added route.
func (siw *ServerInterfaceWrapper) EndLiveActivity(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	ctx = context.WithValue(ctx, PocketbaseTokenScopes, []string{})
	siw.Handler.EndLiveActivity(w, r.WithContext(ctx), r.PathValue("id"))
}
