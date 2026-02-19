# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# Django — Web Patterns (DRF ViewSets, Serializers, Permissions)

## ViewSet Pattern

```python
from rest_framework import viewsets, status
from rest_framework.response import Response

class MerchantViewSet(viewsets.ModelViewSet):
    queryset = Merchant.objects.filter(status="ACTIVE")
    serializer_class = MerchantSerializer
    permission_classes = [IsAuthenticated, HasAPIKey]
    pagination_class = StandardPagination
    filterset_fields = ["mcc", "status"]
    search_fields = ["name", "mid"]
    ordering_fields = ["created_at", "name"]
    ordering = ["-created_at"]

    def get_serializer_class(self):
        if self.action == "create":
            return CreateMerchantSerializer
        return MerchantSerializer

    def perform_destroy(self, instance):
        instance.status = "DELETED"
        instance.save(update_fields=["status", "updated_at"])
```

## Serializers

```python
from rest_framework import serializers

class CreateMerchantSerializer(serializers.Serializer):
    mid = serializers.CharField(max_length=15)
    name = serializers.CharField(max_length=100)
    document = serializers.RegexField(regex=r"^\d{11,14}$")
    mcc = serializers.RegexField(regex=r"^\d{4}$", min_length=4, max_length=4)

    def validate_mid(self, value: str) -> str:
        if Merchant.objects.filter(mid=value).exists():
            raise serializers.ValidationError(f"Merchant with MID '{value}' already exists")
        return value

class MerchantSerializer(serializers.ModelSerializer):
    document_masked = serializers.SerializerMethodField()

    class Meta:
        model = Merchant
        fields = ["id", "mid", "name", "document_masked", "mcc", "status", "created_at"]

    def get_document_masked(self, obj: Merchant) -> str:
        doc = obj.document
        return f"{doc[:3]}****{doc[-2:]}" if len(doc) > 5 else "****"
```

## Custom Permissions

```python
from rest_framework.permissions import BasePermission

class HasAPIKey(BasePermission):
    def has_permission(self, request, view) -> bool:
        api_key = request.headers.get("X-API-Key")
        return api_key == settings.API_KEY
```

## Pagination

```python
from rest_framework.pagination import PageNumberPagination

class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "limit"
    max_page_size = 100
```

## Exception Handling

```python
from rest_framework.views import exception_handler

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is not None:
        response.data = {
            "type": f"/errors/{response.status_code}",
            "title": response.status_text,
            "status": response.status_code,
            "detail": response.data.get("detail", str(response.data)),
            "instance": context["request"].path,
        }
    return response
```

## URL Configuration

```python
from rest_framework.routers import DefaultRouter

router = DefaultRouter()
router.register(r"api/v1/merchants", MerchantViewSet, basename="merchant")
urlpatterns = router.urls
```

## Anti-Patterns

- Do NOT put business logic in views -- use services or model methods
- Do NOT return model instances directly -- always use serializers
- Do NOT skip pagination for list endpoints
- Do NOT use function-based views for CRUD -- use ViewSets
- Do NOT ignore `perform_destroy` for soft deletes
