# -*- coding: utf-8 -*-
"""
Acil Servis Triaj Sınıflandırma - Yapay Sinir Ağları (YSA)
Veri Madenciliği Projesi - 5-Fold Cross Validation

Siniflama:
  - Yesil   (urgency_level = 1, 2): Hafif durum
  - Sari    (urgency_level = 3, 4): Orta aciliyet
  - Kirmizi (urgency_level = 5): Yuksek aciliyet
"""

import json
import os
import warnings
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns

from sklearn.model_selection import StratifiedKFold
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score

import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization, Input
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau

warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['axes.unicode_minus'] = False

# ============================================================
# 1. VERI YUKLEME
# ============================================================
print("=" * 60)
print("  ACIL SERVIS TRIAJ SINIFLANDIRMA - YSA MODELI")
print("  5-FOLD CROSS VALIDATION")
print("=" * 60)

script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(script_dir, ".."))
json_path = os.path.join(project_root, "dataset", "medical_data.json")
output_dir = script_dir

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"\nToplam kayit sayisi: {len(data)}")

# ============================================================
# 2. SINIF ESLEMESI
# ============================================================
def map_triage_class(urgency_level):
    if urgency_level == 1:
        return "Yesil"
    elif urgency_level in [2, 3]:
        return "Sari"
    elif urgency_level in [4, 5]:
        return "Kirmizi"
    else:
        return None

# ============================================================
# 3. SEMPTOM ÖZELLİK ÇIKARMA
# ============================================================
all_symptoms = set()
for record in data:
    for symptom in record.get("symptoms", []):
        all_symptoms.add(symptom.strip().lower())

all_symptoms = sorted(list(all_symptoms))
print(f"Benzersiz semptom sayisi: {len(all_symptoms)}")

rows = []
labels = []
for record in data:
    triage = map_triage_class(record["urgency_level"])
    if triage is None:
        continue
    record_symptoms = set(s.strip().lower() for s in record.get("symptoms", []))
    feature_vector = [1 if symptom in record_symptoms else 0 for symptom in all_symptoms]
    rows.append(feature_vector)
    labels.append(triage)

df = pd.DataFrame(rows, columns=all_symptoms)
df["triage_class"] = labels

csv_path = os.path.join(output_dir, "triage_dataset.csv")
df.to_csv(csv_path, index=False, encoding="utf-8-sig")
print(f"\nVeri seti kaydedildi: {csv_path}")
print(f"Veri seti boyutu: {df.shape[0]} satir x {df.shape[1]} sutun")

print("\nSinif Dagilimi:")
print("-" * 30)
class_counts = df["triage_class"].value_counts()
for cls, count in class_counts.items():
    pct = count / len(df) * 100
    print(f"  {cls:10s}: {count:4d} ({pct:.1f}%)")

# ============================================================
# 4. VERİ HAZIRLAMA
# ============================================================
X = df.drop("triage_class", axis=1).values
y_labels = df["triage_class"].values

le = LabelEncoder()
y_encoded = le.fit_transform(y_labels)

print(f"\nSinif sirasi: {list(le.classes_)}")

# ============================================================
# 5. MODEL OLUŞTURMA FONKSİYONU
# ============================================================
def create_model(input_dim):
    model = Sequential([
        Input(shape=(input_dim,)),
        Dense(128, activation='relu'),
        BatchNormalization(),
        Dropout(0.3),
        Dense(64, activation='relu'),
        BatchNormalization(),
        Dropout(0.3),
        Dense(32, activation='relu'),
        BatchNormalization(),
        Dropout(0.2),
        Dense(3, activation='softmax')
    ])
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

# ============================================================
# 6. 5-FOLD CROSS VALIDATION
# ============================================================
N_FOLDS = 5
print("\n" + "=" * 60)
print(f"  {N_FOLDS}-FOLD CROSS VALIDATION BASLIYOR")
print("=" * 60)

skf = StratifiedKFold(n_splits=N_FOLDS, shuffle=True, random_state=42)

fold_train_acc = []
fold_test_acc = []
fold_train_loss = []
fold_test_loss = []
all_y_true = []
all_y_pred = []
all_histories = []

input_dim = X.shape[1]

for fold_idx, (train_idx, test_idx) in enumerate(skf.split(X, y_encoded), 1):
    print(f"\n{'-' * 60}")
    print(f"  FOLD {fold_idx}/{N_FOLDS}")
    print(f"  Egitim: {len(train_idx)} kayit | Test: {len(test_idx)} kayit")
    print(f"{'-' * 60}")

    X_train, X_test = X[train_idx], X[test_idx]
    y_train = to_categorical(y_encoded[train_idx], num_classes=3)
    y_test = to_categorical(y_encoded[test_idx], num_classes=3)

    model = create_model(input_dim)

    callbacks = [
        EarlyStopping(monitor='val_loss', patience=15,
                      restore_best_weights=True, verbose=0),
        ReduceLROnPlateau(monitor='val_loss', factor=0.5,
                          patience=7, min_lr=1e-6, verbose=0)
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=150,
        batch_size=32,
        callbacks=callbacks,
        verbose=0
    )
    all_histories.append(history)

    tr_loss, tr_acc = model.evaluate(X_train, y_train, verbose=0)
    te_loss, te_acc = model.evaluate(X_test, y_test, verbose=0)

    fold_train_acc.append(tr_acc)
    fold_test_acc.append(te_acc)
    fold_train_loss.append(tr_loss)
    fold_test_loss.append(te_loss)

    y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
    y_true = np.argmax(y_test, axis=1)
    all_y_true.extend(y_true)
    all_y_pred.extend(y_pred)

    print(f"  Egitim Accuracy: %{tr_acc*100:.2f}")
    print(f"  Test Accuracy:   %{te_acc*100:.2f}")

# Son fold'un modelini kaydet
model_path = os.path.join(output_dir, "triage_model.h5")
model.save(model_path)

# ============================================================
# 7. GENEL SONUÇLAR
# ============================================================
all_y_true = np.array(all_y_true)
all_y_pred = np.array(all_y_pred)

print("\n" + "=" * 60)
print(f"  {N_FOLDS}-FOLD CROSS VALIDATION SONUCLARI")
print("=" * 60)

print(f"\n  {'Fold':<8} {'Egitim Acc':>12} {'Test Acc':>12}")
print(f"  {'-'*8} {'-'*12} {'-'*12}")
for i in range(N_FOLDS):
    print(f"  Fold {i+1:<3} {fold_train_acc[i]*100:>11.2f}% {fold_test_acc[i]*100:>11.2f}%")
print(f"  {'-'*8} {'-'*12} {'-'*12}")
print(f"  {'ORT':<8} {np.mean(fold_train_acc)*100:>11.2f}% {np.mean(fold_test_acc)*100:>11.2f}%")
print(f"  {'STD':<8} {np.std(fold_train_acc)*100:>11.2f}% {np.std(fold_test_acc)*100:>11.2f}%")

print(f"\n  Ortalama Egitim Accuracy: %{np.mean(fold_train_acc)*100:.2f} (+/- {np.std(fold_train_acc)*100:.2f})")
print(f"  Ortalama Test Accuracy:   %{np.mean(fold_test_acc)*100:.2f} (+/- {np.std(fold_test_acc)*100:.2f})")

# Tüm fold'ların birleşik confusion matrix ve classification report
print("\n" + "-" * 60)
print(f"  BIRLESIK CLASSIFICATION REPORT ({N_FOLDS} Fold Toplami)")
print("-" * 60)
print(classification_report(all_y_true, all_y_pred, target_names=le.classes_))

cm = confusion_matrix(all_y_true, all_y_pred)
print("Birlesik Confusion Matrix (Tum Fold'lar):")
print(cm)

toplam_test = len(all_y_true)
toplam_dogru = int(accuracy_score(all_y_true, all_y_pred) * toplam_test)
toplam_yanlis = toplam_test - toplam_dogru
print(f"\n  Toplam test edilen: {toplam_test} hasta")
print(f"  Dogru: {toplam_dogru} | Yanlis: {toplam_yanlis}")

# ============================================================
# 8. GÖRSELLEŞTİRME
# ============================================================
print("\n" + "=" * 60)
print("  GORSELLESTIRMELER OLUSTURULUYOR...")
print("=" * 60)

colors = {'Yesil': '#2ecc71', 'Sari': '#f1c40f', 'Kirmizi': '#e74c3c'}

# --- Grafik 1: Fold Bazında Accuracy Karşılaştırma ---
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

fold_labels = [f'Fold {i+1}' for i in range(N_FOLDS)]
x = np.arange(N_FOLDS)
width = 0.35

bars1 = axes[0].bar(x - width/2, [a*100 for a in fold_train_acc], width,
                     label='Egitim', color='#3498db', edgecolor='white')
bars2 = axes[0].bar(x + width/2, [a*100 for a in fold_test_acc], width,
                     label='Test', color='#e74c3c', edgecolor='white')

for bar in bars1:
    axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                 f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)
for bar in bars2:
    axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                 f'{bar.get_height():.1f}%', ha='center', va='bottom', fontsize=8)

axes[0].set_title(f'{N_FOLDS}-Fold Accuracy Karsilastirma', fontsize=14, fontweight='bold')
axes[0].set_xlabel('Fold')
axes[0].set_ylabel('Accuracy (%)')
axes[0].set_xticks(x)
axes[0].set_xticklabels(fold_labels)
axes[0].legend(fontsize=11)
axes[0].grid(axis='y', alpha=0.3)
axes[0].set_ylim(0, 110)

# Ortalama çizgileri
axes[0].axhline(y=np.mean(fold_train_acc)*100, color='#3498db',
                linestyle='--', alpha=0.7, label=f'Ort. Egitim: {np.mean(fold_train_acc)*100:.1f}%')
axes[0].axhline(y=np.mean(fold_test_acc)*100, color='#e74c3c',
                linestyle='--', alpha=0.7, label=f'Ort. Test: {np.mean(fold_test_acc)*100:.1f}%')
axes[0].legend(fontsize=9)

# Son fold'un eğitim eğrileri
last_hist = all_histories[-1]
axes[1].plot(last_hist.history['accuracy'], label='Egitim Accuracy', color='#3498db', linewidth=2)
axes[1].plot(last_hist.history['val_accuracy'], label='Test Accuracy', color='#e74c3c', linewidth=2)
axes[1].set_title('Son Fold - Egitim Egrisi', fontsize=14, fontweight='bold')
axes[1].set_xlabel('Epoch')
axes[1].set_ylabel('Accuracy')
axes[1].legend(fontsize=11)
axes[1].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(os.path.join(output_dir, "accuracy_loss_grafik.png"), dpi=150, bbox_inches='tight')
plt.close()
print("  [OK] accuracy_loss_grafik.png")

# --- Grafik 2: Birleşik Confusion Matrix ---
fig, ax = plt.subplots(figsize=(8, 6))
sns.heatmap(cm, annot=True, fmt='d', cmap='YlOrRd',
            xticklabels=le.classes_, yticklabels=le.classes_,
            ax=ax, cbar_kws={'label': 'Sayi'})
ax.set_title(f'Birlesik Confusion Matrix ({N_FOLDS}-Fold, {toplam_test} Test)',
             fontsize=14, fontweight='bold')
ax.set_xlabel('Tahmin Edilen Sinif', fontsize=12)
ax.set_ylabel('Gercek Sinif', fontsize=12)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, "confusion_matrix.png"), dpi=150, bbox_inches='tight')
plt.close()
print("  [OK] confusion_matrix.png")

# --- Grafik 3: Sınıf Dağılımı ---
fig, ax = plt.subplots(figsize=(8, 5))
class_names = class_counts.index.tolist()
class_values = class_counts.values.tolist()
bar_colors = [colors.get(c, '#95a5a6') for c in class_names]
bars = ax.bar(class_names, class_values, color=bar_colors, edgecolor='white', linewidth=1.5)
for bar, val in zip(bars, class_values):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 5,
            str(val), ha='center', va='bottom', fontweight='bold', fontsize=13)
ax.set_title('Triaj Sinif Dagilimi', fontsize=14, fontweight='bold')
ax.set_xlabel('Triaj Sinifi', fontsize=12)
ax.set_ylabel('Hasta Sayisi', fontsize=12)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(output_dir, "sinif_dagilimi.png"), dpi=150, bbox_inches='tight')
plt.close()
print("  [OK] sinif_dagilimi.png")

# --- Grafik 4: Performans Metrikleri ---
report_dict = classification_report(all_y_true, all_y_pred, target_names=le.classes_, output_dict=True)
fig, ax = plt.subplots(figsize=(10, 6))
classes = list(le.classes_)
precision = [report_dict[c]['precision'] for c in classes]
recall = [report_dict[c]['recall'] for c in classes]
f1 = [report_dict[c]['f1-score'] for c in classes]

x = np.arange(len(classes))
width = 0.25
bars1 = ax.bar(x - width, precision, width, label='Precision', color='#3498db', edgecolor='white')
bars2 = ax.bar(x, recall, width, label='Recall', color='#2ecc71', edgecolor='white')
bars3 = ax.bar(x + width, f1, width, label='F1-Score', color='#e74c3c', edgecolor='white')

ax.set_title(f'Sinif Bazinda Performans ({N_FOLDS}-Fold Ortalama)', fontsize=14, fontweight='bold')
ax.set_xlabel('Triaj Sinifi', fontsize=12)
ax.set_ylabel('Skor', fontsize=12)
ax.set_xticks(x)
ax.set_xticklabels(classes)
ax.legend(fontsize=11)
ax.set_ylim(0, 1.15)
ax.grid(axis='y', alpha=0.3)

for bars in [bars1, bars2, bars3]:
    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, h + 0.02,
                f'{h:.2f}', ha='center', va='bottom', fontsize=9)

plt.tight_layout()
plt.savefig(os.path.join(output_dir, "performans_metrikleri.png"), dpi=150, bbox_inches='tight')
plt.close()
print("  [OK] performans_metrikleri.png")

# ============================================================
# 9. ÖZET
# ============================================================
print("\n" + "=" * 60)
print("  SONUC OZETI")
print("=" * 60)
print(f"""
  Veri Seti:            {df.shape[0]} kayit, {df.shape[1]-1} ozellik
  Sinif Sayisi:         3 (Yesil, Sari, Kirmizi)
  Cross Validation:     {N_FOLDS}-Fold
  
  Ort. Egitim Accuracy: %{np.mean(fold_train_acc)*100:.2f} (+/- {np.std(fold_train_acc)*100:.2f})
  Ort. Test Accuracy:   %{np.mean(fold_test_acc)*100:.2f} (+/- {np.std(fold_test_acc)*100:.2f})
  
  Toplam Test Edilen:   {toplam_test} hasta
  Dogru Siniflandirma:  {toplam_dogru} hasta
  Yanlis Siniflandirma: {toplam_yanlis} hasta
  
  Olusturulan Dosyalar:
    - triage_dataset.csv
    - triage_model.h5
    - accuracy_loss_grafik.png
    - confusion_matrix.png
    - sinif_dagilimi.png
    - performans_metrikleri.png
""")
print("=" * 60)
print("  TAMAMLANDI!")
print("=" * 60)
