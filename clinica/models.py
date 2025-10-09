from django.db import models
from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator, FileExtensionValidator
from django.contrib.contenttypes.fields import GenericForeignKey
from django.db.models import Q
from django.core.exceptions import ValidationError


def avatar_upload_to(instance, filename):
    model = instance.__class__.__name__.lower() # patient или doctor
    return f'avatars/{model}/{filename}'

class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, verbose_name='Создано')
    updated_at = models.DateTimeField(auto_now=True, verbose_name='Обновлено')
    class Meta:
        abstract = True

class ContactBase(models.Model):
    full_name = models.CharField('Имя', max_length=255)
    nickname = models.CharField('Никнейм', max_length=64, unique=True)
    telegram = models.CharField('Контакт Telegram', max_length=64, blank=True)
    avatar = models.ImageField('Аватар', upload_to=avatar_upload_to, blank=True, null=True,
                               validators=[FileExtensionValidator(['jpg', 'jpeg', 'png', 'webp'])])
    class Meta:
        abstract = True
class MentalStatePreset(models.Model):
    level = models.SmallIntegerField( unique=True, validators=[MinValueValidator(-3), MaxValueValidator(3)], verbose_name='Уровень' )
    description = models.TextField('Описание', blank=True)

    class Meta:
        verbose_name = 'Шаблон ментального состояния'
        verbose_name_plural = 'Шаблоны ментальных состояний'
        ordering = ['level']

    def __str__(self):
        return f'Уровень {self.level}'

class MentalState(TimeStampedModel):
    level = models.SmallIntegerField( 'Уровень ментального состояния', validators=[MinValueValidator(-3), MaxValueValidator(3)], default=0 )
    description = models.TextField('Описание состояния', blank=True)
    def __str__(self):
        return f'Ментальное состояние {self.level}'

class Patient(ContactBase, TimeStampedModel):
    ser = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, null=True, blank=True,
                               related_name='patient_profile', verbose_name='Пользователь')
    chemistry_level = models.PositiveSmallIntegerField( 'Уровень химии', default=1, validators=[MinValueValidator(1), MaxValueValidator(3)])
    mechanics_level = models.PositiveSmallIntegerField( 'Уровень механики', default=1, validators=[MinValueValidator(1), MaxValueValidator(3)])
    social_skills_level = models.PositiveSmallIntegerField( 'Уровень социальных навыков', default=1, validators=[MinValueValidator(1), MaxValueValidator(3)])
    physical_skills_level = models.PositiveSmallIntegerField( 'Уровень физических навыков', default=1, validators=[MinValueValidator(1), MaxValueValidator(3)])
    bonus_level = models.TextField( 'Дополнительные свойства')
    mental_state = models.OneToOneField(MentalState, on_delete=models.CASCADE, null=True, blank=True,
                                        related_name='patient', verbose_name='Ментальное состояние')
    def __str__(self):
        return f'Пациент {self.full_name} (@{self.nickname})'

class Doctor(ContactBase, TimeStampedModel):
    # Опционально: связать врача с учетной записью пользователя для реальных прав доступа
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True, blank=True,
        related_name='doctor_profile',
        verbose_name='Пользователь'
    )
    class Meta:
        permissions = [
            ('can_edit_patients', 'Может редактировать данные пациентов'),
        ]
    def __str__(self):
        return f'Врач {self.full_name} (@{self.nickname})'

class NightmareMap(TimeStampedModel):
    patient = models.OneToOneField(Patient, on_delete=models.CASCADE, related_name='nightmare_map', verbose_name='Пациент')
    property_1_condition = models.TextField('Условие активации свойства 1', blank=True)
    property_1_description = models.TextField('Описание свойства 1', blank=True)

    property_2_condition = models.TextField('Условие активации свойства 2', blank=True)
    property_2_description = models.TextField('Описание свойства 2', blank=True)

    property_3_condition = models.TextField('Условие активации свойства 3', blank=True)
    property_3_description = models.TextField('Описание свойства 3', blank=True)

    property_4_condition = models.TextField('Условие активации свойства 4', blank=True)
    property_4_description = models.TextField('Описание свойства 4', blank=True)

    extra_property_1_description = models.TextField('Описание доп. свойства 1', blank=True)

    extra_property_2_description = models.TextField('Описание доп. свойства 2', blank=True)
    def __str__(self):
        return f'Карта кошмара: {self.patient.full_name}'

class AwarenessMap(TimeStampedModel):
    patient = models.OneToOneField( Patient, on_delete=models.CASCADE, related_name='awareness_map', verbose_name='Пациент' )
    property_1_condition = models.TextField('Условие активации свойства 1', blank=True)
    property_1_description = models.TextField('Описание свойства 1', blank=True)

    property_2_condition = models.TextField('Условие активации свойства 2', blank=True)
    property_2_description = models.TextField('Описание свойства 2', blank=True)

    property_3_condition = models.TextField('Условие активации свойства 3', blank=True)
    property_3_description = models.TextField('Описание свойства 3', blank=True)

    property_4_condition = models.TextField('Условие активации свойства 4', blank=True)
    property_4_description = models.TextField('Описание свойства 4', blank=True)

    extra_property_1_description = models.TextField('Описание доп. свойства 1', blank=True)
    extra_property_2_description = models.TextField('Описание доп. свойства 2', blank=True)
    def __str__(self):
        return f'Карта осознания: {self.patient.full_name}'

class AuthorMixin(models.Model):
    # Автором может быть Пациент или Врач
    author = GenericForeignKey('author_content_type', 'author_object_id')
    class Meta:
        abstract = True

class AbstractCompound(TimeStampedModel):
    # Владелец записи — пациент
    owner = models.ForeignKey(
        Patient,
        on_delete=models.CASCADE,
        related_name='%(class)ss',
        verbose_name='Пациент-владелец'
    )
    # Автор — либо пациент, либо врач (ровно один)
    author_patient = models.ForeignKey(
        Patient,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='%(class)ss_authored_as_patient',
        verbose_name='Автор (пациент)'
    )
    author_doctor = models.ForeignKey(
        Doctor,
        on_delete=models.SET_NULL,
        null=True, blank=True,
        related_name='%(class)ss_authored_as_doctor',
        verbose_name='Автор (врач)'
    )

    property_1 = models.CharField('Свойство 1', max_length=255)
    property_2 = models.CharField('Свойство 2', max_length=255)
    property_3 = models.CharField('Свойство 3', max_length=255)
    duration = models.DurationField('Время действия')
    extra_property = models.CharField('Доп. свойство', max_length=255, blank=True)
    class Meta:
        abstract = True
        constraints = [
            # Ровно одно поле автора должно быть заполнено
            models.CheckConstraint(
                name='%(app_label)s_%(class)s_exactly_one_author',
                check=(
                    (Q(author_patient__isnull=False) & Q(author_doctor__isnull=True)) |
                    (Q(author_patient__isnull=True) & Q(author_doctor__isnull=False))),)
        ]
    def clean(self):
        super().clean()
        if bool(self.author_patient) == bool(self.author_doctor):
            raise ValidationError('Укажите либо автора-пациента, либо автора-врача (ровно одно поле).')
    @property
    def author(self):
        return self.author_patient or self.author_doctor

    def author_str(self):
        if self.author_patient:
            return f'Пациент: {self.author_patient.full_name}'
        if self.author_doctor:
            return f'Врач: {self.author_doctor.full_name}'
        return 'Автор не указан'


class ChemicalRecipe(AbstractCompound):
    class Meta:
        verbose_name = 'Химический рецепт'
        verbose_name_plural = 'Химические рецепты'
    def __str__(self):
        return f'Химический рецепт для {self.owner.full_name} (авт. {self.author_str()})'

class MechanicalCompound(AbstractCompound):
    class Meta:
        verbose_name = 'Механическое соединение'
        verbose_name_plural = 'Механические соединения'
    def __str__(self):
        return f'Механическое соединение для {self.owner.full_name} (авт. {self.author_str()})'
